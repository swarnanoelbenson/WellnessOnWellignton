import 'admin_user.dart';
import 'attendance_record.dart';
import 'employee.dart';

// ── Clock-In Results ─────────────────────────────────────────────────────────

/// All possible outcomes of an employee clock-in attempt.
sealed class ClockInResult {
  const ClockInResult();
}

/// Password verified; [record] was created and persisted to SQLite.
final class ClockInSuccess extends ClockInResult {
  final AttendanceRecord record;
  ClockInSuccess(this.record);
}

/// Password matched "123456" AND [employee.isDefaultPassword] was true.
///
/// The [pendingRecord] is held in memory but NOT yet persisted.
/// The UI must show [SetPasswordModal] and then call
/// [AuthService.completeClockInWithSetup] to finalise both the password
/// change and the clock-in atomically.
final class ClockInRequiresPasswordSetup extends ClockInResult {
  final Employee employee;
  final AttendanceRecord pendingRecord;

  ClockInRequiresPasswordSetup({
    required this.employee,
    required this.pendingRecord,
  });
}

/// The submitted password did not match the stored bcrypt hash.
final class ClockInWrongPassword extends ClockInResult {
  const ClockInWrongPassword();
}

/// The employee already has an open (not yet clocked-out) record today.
/// The [existing] record is provided so the UI can show the clock-in time.
final class ClockInAlreadyClockedIn extends ClockInResult {
  final AttendanceRecord existing;
  ClockInAlreadyClockedIn(this.existing);
}

// ── Clock-Out Results ────────────────────────────────────────────────────────

/// All possible outcomes of an employee clock-out attempt.
sealed class ClockOutResult {
  const ClockOutResult();
}

/// Password verified; [record] has been updated with clock-out time and
/// total hours, and persisted to SQLite.
final class ClockOutSuccess extends ClockOutResult {
  final AttendanceRecord record;
  ClockOutSuccess(this.record);
}

/// The submitted password did not match the stored bcrypt hash.
final class ClockOutWrongPassword extends ClockOutResult {
  const ClockOutWrongPassword();
}

/// The record already has a clock-out time — cannot clock out a second time.
final class ClockOutAlreadyCompleted extends ClockOutResult {
  const ClockOutAlreadyCompleted();
}

// ── Admin Login Results ──────────────────────────────────────────────────────

/// All possible outcomes of an admin login attempt.
sealed class AdminLoginResult {
  const AdminLoginResult();
}

/// Credentials verified; [admin] is the authenticated account.
final class AdminLoginSuccess extends AdminLoginResult {
  final AdminUser admin;
  AdminLoginSuccess(this.admin);
}

/// Username not found or password incorrect.
/// No detail is exposed to avoid username enumeration.
final class AdminLoginFailure extends AdminLoginResult {
  const AdminLoginFailure();
}
