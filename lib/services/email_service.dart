import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../config/email_config.dart';
import '../data/database/database_helper.dart';
import '../services/admin_service.dart';

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
  EmailService({required DatabaseHelper db}) : _db = db;

  final DatabaseHelper _db;
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
      final csv = AdminService.generateCsv(records);
      final sent = await sendReport(from: today, to: today, csv: csv);
      if (!sent) {
        debugPrint('[Email] Auto-send failed (see above); will retry tomorrow.');
      }
    } catch (e) {
      debugPrint('[Email] Auto-send error: $e');
    }

    _scheduleNext();
  }

  // ── Manual / SMTP send ────────────────────────────────────────────────────

  /// Sends [csv] to [EmailConfig.reportRecipients] via Gmail SMTP
  /// (smtp.gmail.com, port 587, STARTTLS).
  ///
  /// Returns `true` on success, `false` on any failure.
  /// Logs all outcomes via [debugPrint].
  ///
  /// Does nothing and returns `false` when [EmailConfig.isConfigured] is
  /// false — the caller should fall back to the device mail app.
  Future<bool> sendReport({
    required DateTime from,
    required DateTime to,
    required String csv,
  }) async {
    if (!EmailConfig.isConfigured) {
      debugPrint('[Email] Gmail credentials not configured — skipping send.');
      return false;
    }

    final subject = _buildSubject(from, to);
    final dateTag =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final filename = from == to
        ? 'attendance_$dateTag.csv'
        : 'attendance_${dateTag}_to_'
            '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}'
            '.csv';

    final present =
        csv.split('\n').skip(1).where((l) => l.contains('Complete')).length;
    final missing = csv
        .split('\n')
        .skip(1)
        .where((l) => l.contains('Missing Clock-Out'))
        .length;
    final absent =
        csv.split('\n').skip(1).where((l) => l.contains('Absent')).length;

    final bodyText = '''$subject

Summary
───────────────────────
Present (complete):     $present
Missing clock-out:      $missing
Absent:                 $absent

The full attendance log is attached as a CSV file.

─────────────────────────────────────────────────
Sent automatically by Wellness on Wellington
''';

    // smtp.gmail.com:587 with STARTTLS — requires a Google App Password.
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
      ..attachments.add(
        StreamAttachment(
          Stream.fromIterable([utf8.encode(csv)]),
          'text/csv',
          fileName: filename,
        ),
      );

    try {
      final report = await send(message, smtpServer);
      debugPrint('[Email] Report "$subject" sent — $report');
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
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final isSingleDay =
        from.year == to.year && from.month == to.month && from.day == to.day;
    final dateRange = isSingleDay ? fmt(from) : '${fmt(from)} to ${fmt(to)}';
    return 'Wellness on Wellington — Attendance Report $dateRange';
  }
}
