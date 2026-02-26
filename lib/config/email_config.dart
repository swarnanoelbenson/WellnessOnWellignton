import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for the automated daily attendance email.
///
/// ## Setup instructions
/// 1. Copy `.env.example` to `.env` at the project root.
/// 2. Enable 2-Step Verification on the Gmail account.
/// 3. Generate a Google App Password (Security → App Passwords).
/// 4. Fill in `GMAIL_SENDER` and `GMAIL_APP_PASSWORD` in `.env`.
///
/// `.env` is listed in `.gitignore` and is loaded at startup via
/// [dotenv].  Secrets never appear as compile-time constants in
/// source code or the compiled binary's string table.
abstract class EmailConfig {
  EmailConfig._();

  // ── Gmail SMTP ────────────────────────────────────────────────────────────

  /// Gmail address used to authenticate with smtp.gmail.com.
  /// Read at runtime from `GMAIL_SENDER` in `.env`.
  static String get gmailSender => dotenv.env['GMAIL_SENDER'] ?? '';

  /// Google App Password for [gmailSender].
  /// Read at runtime from `GMAIL_APP_PASSWORD` in `.env`.
  static String get gmailAppPassword =>
      dotenv.env['GMAIL_APP_PASSWORD'] ?? '';

  // ── Sender display name ───────────────────────────────────────────────────

  /// Display name shown in the From field of outgoing emails.
  static const String senderName = 'Wellness on Wellington';

  // ── Recipients ────────────────────────────────────────────────────────────

  /// All addresses that receive the daily attendance report.
  static const List<String> reportRecipients = [
    'swarnanoelbenson@gmail.com',
  ];

  // ── Guard ─────────────────────────────────────────────────────────────────

  /// True when both Gmail credentials have been loaded from `.env` and
  /// recipients are set.  Used to gate the SMTP code path; falls back to the
  /// device mail app when false.
  static bool get isConfigured =>
      gmailSender.isNotEmpty &&
      gmailAppPassword.isNotEmpty &&
      reportRecipients.isNotEmpty;
}
