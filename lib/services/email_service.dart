import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../config/email_config.dart';
import '../data/database/database_helper.dart';
import '../services/admin_service.dart';
import '../services/board_reset_service.dart';

/// Handles the daily scheduled attendance email and manual report sending.
///
/// ## Scheduling
/// Call [startScheduler] once from the main screen's [initState].  The
/// service calculates the next send time based on the clinic's workday
/// timetable and public holidays stored in SQLite, then sets a [Timer].
/// When the timer fires it fetches today's records, generates a CSV, sends
/// via Gmail SMTP, and reschedules for the following day automatically.
///
/// ## Schedule (email sent 1 hour after closing)
/// ```
/// Mon–Thu  close 9 pm  → email 10 pm
/// Fri      close 7 pm  → email  8 pm
/// Sat–Sun  close 5 pm  → email  6 pm
/// Holiday  close 1 pm  → email  2 pm
/// ```
///
/// ## Sending
/// [sendReport] connects to smtp.gmail.com:587 (STARTTLS) using the
/// credentials in [EmailConfig] and returns `true` on success.
/// If [EmailConfig.isConfigured] is false the call is skipped and `false` is
/// returned so callers can fall back to the device mail app.
class EmailService {
  EmailService({
    required DatabaseHelper db,
    this.onReportSent,
  }) : _db = db;

  final DatabaseHelper _db;

  /// Called after every successful email send (scheduled or manual).
  /// Use this to invalidate board providers so the UI resets immediately.
  final VoidCallback? onReportSent;

  Timer? _dailyTimer;

  // Weekday (DateTime.monday == 1 … DateTime.sunday == 7) → send hour (24 h).
  static const Map<int, int> _sendHour = {
    DateTime.monday: 22,
    DateTime.tuesday: 22,
    DateTime.wednesday: 22,
    DateTime.thursday: 22,
    DateTime.friday: 20,
    DateTime.saturday: 18,
    DateTime.sunday: 18,
  };
  static const int _holidaySendHour = 14; // 2 pm on public holidays

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Starts the daily scheduling loop.  Safe to call multiple times —
  /// cancels any in-flight timer before rescheduling.
  void startScheduler() {
    debugPrint('[Email] Scheduler started.');
    _scheduleNext();
  }

  /// Cancels the pending timer.  Called via [ref.onDispose] in the provider.
  void dispose() {
    _dailyTimer?.cancel();
    debugPrint('[Email] Scheduler stopped.');
  }

  // ── Scheduling ────────────────────────────────────────────────────────────

  Future<void> _scheduleNext() async {
    final now = DateTime.now();
    final sendTime = await _nextSendTime(now);
    final delay = sendTime.difference(now);

    debugPrint(
      '[Email] Next report scheduled for '
      '${sendTime.toIso8601String().substring(0, 16)} '
      '(in ${delay.inMinutes} min)',
    );

    _dailyTimer?.cancel();
    _dailyTimer = Timer(delay, _fireDailyReport);
  }

  /// Returns the next [DateTime] at which a report should be sent.
  ///
  /// If today's send time is still in the future it returns that; otherwise
  /// it returns tomorrow's send time.
  Future<DateTime> _nextSendTime(DateTime now) async {
    final todaySend = await _sendTimeForDate(now);
    if (todaySend.isAfter(now)) return todaySend;
    return _sendTimeForDate(now.add(const Duration(days: 1)));
  }

  /// Returns the scheduled send [DateTime] for [date] (at minute 00).
  Future<DateTime> _sendTimeForDate(DateTime date) async {
    final isHoliday = await _db.isPublicHoliday(date);
    final hour =
        isHoliday ? _holidaySendHour : (_sendHour[date.weekday] ?? 22);
    return DateTime(date.year, date.month, date.day, hour, 0);
  }

  // ── Auto-send ─────────────────────────────────────────────────────────────

  /// Called by the timer.  Fetches today's records, sends the report, then
  /// reschedules for the following day.
  Future<void> _fireDailyReport() async {
    final today = DateTime.now();
    debugPrint(
        '[Email] Auto-sending daily report for ${today.toIso8601String().substring(0, 10)}');

    try {
      final records = await _db.getAttendanceForDate(today);
      final employees = await _db.getAllEmployees();
      final detailed = AdminService.generateDetailedCsv(employees, records);
      final summary = AdminService.generateSummaryCsv(employees, records);
      final sent = await sendReport(
        from: today,
        to: today,
        detailedCsv: detailed,
        summaryCsv: summary,
      );
      if (!sent) {
        debugPrint('[Email] Auto-send failed (see above); will retry tomorrow.');
      }
    } catch (e) {
      debugPrint('[Email] Auto-send error: $e');
    }

    _scheduleNext();
  }

  // ── Manual / SMTP send ────────────────────────────────────────────────────

  /// Sends two CSV attachments (detailed + summary) to
  /// [EmailConfig.reportRecipients] via Gmail SMTP (smtp.gmail.com:587,
  /// STARTTLS).
  ///
  /// Returns `true` on success, `false` on any failure.
  /// Does nothing and returns `false` when [EmailConfig.isConfigured] is false.
  Future<bool> sendReport({
    required DateTime from,
    required DateTime to,
    required String detailedCsv,
    required String summaryCsv,
  }) async {
    if (!EmailConfig.isConfigured) {
      debugPrint('[Email] Gmail credentials not configured — skipping send.');
      return false;
    }

    final subject = _buildSubject(from, to);
    final isSingleDay =
        from.year == to.year && from.month == to.month && from.day == to.day;
    final dateTag = isSingleDay
        ? '${from.day.toString().padLeft(2, '0')}-'
          '${from.month.toString().padLeft(2, '0')}-'
          '${from.year}'
        : '${from.day.toString().padLeft(2, '0')}-'
          '${from.month.toString().padLeft(2, '0')}-'
          '${from.year}_to_'
          '${to.day.toString().padLeft(2, '0')}-'
          '${to.month.toString().padLeft(2, '0')}-'
          '${to.year}';

    final detailedFilename = 'wellness_attendance_detailed_$dateTag.csv';
    final summaryFilename  = 'wellness_attendance_summary_$dateTag.csv';

    // Count summary stats from the summary CSV (skip header row).
    final summaryLines = summaryCsv.split('\n').skip(1);
    final present = summaryLines.where((l) => l.contains('Complete')).length;
    final missing = summaryLines.where((l) => l.contains('Missing Clock-Out')).length;
    final absent  = summaryLines.where((l) => l.contains('Absent')).length;

    final bodyText = '''$subject

Attachments
───────────────────────────────────────────────
• $detailedFilename
  Detailed Report — for internal finance review.
  Shows each clock-in/clock-out session with per-employee totals.

• $summaryFilename
  Summary Report — for payroll software upload.
  One row per employee with total hours for the day.

Summary
───────────────────────
Present (complete):     $present
Missing clock-out:      $missing
Absent:                 $absent

─────────────────────────────────────────────────
Sent automatically by Wellness on Wellington
''';

    final smtpServer = SmtpServer(
      'smtp.gmail.com',
      port: 587,
      username: EmailConfig.gmailSender,
      password: EmailConfig.gmailAppPassword,
    );

    final message = Message()
      ..from = Address(EmailConfig.gmailSender, EmailConfig.senderName)
      ..recipients.addAll(
          EmailConfig.reportRecipients.map((email) => Address(email)))
      ..subject = subject
      ..text = bodyText
      ..attachments.add(StreamAttachment(
        Stream.fromIterable([utf8.encode(detailedCsv)]),
        'text/csv',
        fileName: detailedFilename,
      ))
      ..attachments.add(StreamAttachment(
        Stream.fromIterable([utf8.encode(summaryCsv)]),
        'text/csv',
        fileName: summaryFilename,
      ));

    try {
      final report = await send(message, smtpServer);
      debugPrint('[Email] Report "$subject" sent — $report');
      await BoardResetService.markReset();
      onReportSent?.call();
      return true;
    } on MailerException catch (e) {
      debugPrint('[Email] SMTP error: ${e.message}');
      for (final p in e.problems) {
        debugPrint('[Email]   ${p.code}: ${p.msg}');
      }
      return false;
    } catch (e) {
      debugPrint('[Email] Error: $e');
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _buildSubject(DateTime from, DateTime to) {
    String dmY(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';

    final isSingleDay =
        from.year == to.year && from.month == to.month && from.day == to.day;
    final dateRange = isSingleDay ? dmY(from) : '${dmY(from)} to ${dmY(to)}';
    return 'Wellness on Wellington – Attendance Report $dateRange';
  }
}
