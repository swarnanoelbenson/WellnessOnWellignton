import 'package:bcrypt/bcrypt.dart';

/// Central utility for all password hashing and verification.
///
/// Uses bcrypt — passwords are NEVER stored or compared in plain text.
/// All calls to [hashPassword] and [verifyPassword] go through this class.
class PasswordUtils {
  PasswordUtils._(); // static-only class

  /// The system default password assigned to every new employee.
  /// Employees are forced to change this on their first clock-in.
  static const String defaultPassword = '123456';

  /// Valid password length range (inclusive) per the spec.
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 12;

  /// Returns a bcrypt hash of [plainText] using a freshly generated salt.
  /// This is intentionally slow — appropriate for password storage.
  static String hashPassword(String plainText) {
    return BCrypt.hashpw(plainText, BCrypt.gensalt());
  }

  /// Returns true if [plainText] matches the stored [hash].
  static bool verifyPassword(String plainText, String hash) {
    return BCrypt.checkpw(plainText, hash);
  }

  /// Convenience: returns a bcrypt hash of the default password "123456".
  /// Called when adding a new employee via the Admin Panel.
  static String get hashedDefaultPassword => hashPassword(defaultPassword);

  /// Returns true if [password] satisfies the length constraint.
  static bool isValidLength(String password) {
    return password.length >= minPasswordLength &&
        password.length <= maxPasswordLength;
  }

  /// Returns true if [password] is the literal default password string.
  /// This is only used in display/hint logic — never for authentication.
  static bool isDefaultPassword(String password) {
    return password == defaultPassword;
  }
}
