/// Configuration for the automated daily attendance email.
///
/// ## Setup instructions
/// 1. Create a free SendGrid account at https://sendgrid.com
/// 2. Verify your sender domain/address in SendGrid.
/// 3. Generate an API key with "Mail Send" permission.
/// 4. Replace the placeholder values below with your real values.
///
/// ⚠  Never commit a real API key to source control.
///    Use environment injection or a secrets manager for production.
abstract class EmailConfig {
  EmailConfig._();

  // ── SendGrid ──────────────────────────────────────────────────────────────

  /// SendGrid API key.  Replace with your real key before deploying.
  static const String sendGridApiKey = 'YOUR_SENDGRID_API_KEY';

  // ── Sender ────────────────────────────────────────────────────────────────

  /// The "From" address shown on automated report emails.
  /// Must be verified in your SendGrid account.
  static const String senderEmail = 'attendance@wellnessonwellington.com';

  /// Display name shown alongside [senderEmail].
  static const String senderName = 'Wellness on Wellington';

  // ── Recipients ────────────────────────────────────────────────────────────

  /// All addresses that receive the daily attendance report.
  static const List<String> reportRecipients = [
    'manager@wellnessonwellington.com',
  ];

  // ── Guard ─────────────────────────────────────────────────────────────────

  /// True when the API key has been filled in and recipients are set.
  ///
  /// Used to gate the SendGrid code path; falls back to the device mail
  /// app when false.
  static bool get isConfigured =>
      sendGridApiKey.isNotEmpty &&
      sendGridApiKey != 'YOUR_SENDGRID_API_KEY' &&
      reportRecipients.isNotEmpty;
}
