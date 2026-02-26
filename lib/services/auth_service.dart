import '../data/database/database_helper.dart';
import '../data/firebase/firestore_service.dart';
import '../models/admin_user.dart';
import '../models/attendance_record.dart';
import '../models/auth_result.dart';
import '../models/employee.dart';
import '../utils/password_utils.dart';

/// Central authentication service for Wellness on Wellington.
///
/// All auth decisions go through this class.  Passwords are NEVER compared
/// in plain text — every verification delegates to [PasswordUtils].
///
/// ## Design
/// The class exposes two tiers of methods:
///
/// **Static pure-logic helpers** (no I/O):
/// These take plain Dart objects and return typed result values.  They are
/// deterministic and trivially unit-testable without any database setup.
///
/// **Async composite methods** (logic + persistence):
/// Each combines the corresponding pure helper with SQLite writes (via
/// [DatabaseHelper]) and fire-and-forget Firestore sync (via
/// [FirestoreService]).  Pass a null [firestore] to skip cloud sync (useful
/// in tests or when Firebase is not yet configured).
class AuthService {
  AuthService({
    required DatabaseHelper db,
    FirestoreService? firestore,
  })  : _db = db,
        _firestore = firestore;

  final DatabaseHelper _db;
  final FirestoreService? _firestore;

  // ── Static pure-logic helpers ────────────────────────────────────────────

  /// Returns true if [plainText] matches [employee]'s bcrypt hash.
  static bool verifyEmployeePassword(Employee employee, String plainText) =>
      PasswordUtils.verifyPassword(plainText, employee.passwordHash);

  /// Determines the correct [ClockInResult] from the given data.
  ///
  /// Priority order:
  ///   1. Already clocked in (open record exists) → [ClockInAlreadyClockedIn]
  ///   2. Wrong password                           → [ClockInWrongPassword]
  ///   3. First-time login (isDefaultPassword)     → [ClockInRequiresPasswordSetup]
  ///   4. Normal login                             → [ClockInSuccess] with a
  ///      NEW (not yet persisted) [AttendanceRecord]
  ///
  /// The [pendingRecord] inside [ClockInSuccess] / [ClockInRequiresPasswordSetup]
  /// must be persisted by the caller (the composite [clockIn] method does this).
  static ClockInResult buildClockInResult({
    required Employee employee,
    required String password,
    required AttendanceRecord? existingRecord,
    required DateTime now,
  }) {
    // Guard: already clocked in with no clock-out yet.
    if (existingRecord != null && existingRecord.clockOutTime == null) {
      return ClockInAlreadyClockedIn(existingRecord);
    }

    // Verify password before anything else.
    if (!verifyEmployeePassword(employee, password)) {
      return const ClockInWrongPassword();
    }

    final pending = AttendanceRecord.clockIn(
      employeeId: employee.id,
      employeeName: employee.name,
      clockInTime: now,
    );

    // First-time login: do not persist yet — UI must collect a new password.
    if (employee.isDefaultPassword) {
      return ClockInRequiresPasswordSetup(
        employee: employee,
        pendingRecord: pending,
      );
    }

    return ClockInSuccess(pending);
  }

  /// Determines the correct [ClockOutResult] from the given data.
  ///
  /// Priority order:
  ///   1. Record already has a clock-out time → [ClockOutAlreadyCompleted]
  ///   2. Wrong password                      → [ClockOutWrongPassword]
  ///   3. Success                             → [ClockOutSuccess] with the
  ///      updated record (not yet persisted)
  static ClockOutResult buildClockOutResult({
    required Employee employee,
    required AttendanceRecord record,
    required String password,
    required DateTime now,
  }) {
    if (record.clockOutTime != null) {
      return const ClockOutAlreadyCompleted();
    }
    if (!verifyEmployeePassword(employee, password)) {
      return const ClockOutWrongPassword();
    }
    return ClockOutSuccess(record.withClockOut(now));
  }

  /// Determines the [AdminLoginResult] from a (possibly null) [admin] lookup
  /// and a plain-text [password].
  ///
  /// Passing null for [admin] (username not found) returns
  /// [AdminLoginFailure] — no detail is given to the caller to prevent
  /// username enumeration.
  static AdminLoginResult buildAdminLoginResult({
    required AdminUser? admin,
    required String password,
  }) {
    if (admin == null) return const AdminLoginFailure();
    if (!PasswordUtils.verifyPassword(password, admin.passwordHash)) {
      return const AdminLoginFailure();
    }
    return AdminLoginSuccess(admin);
  }

  // ── Async composite methods (logic + SQLite + Firestore sync) ────────────

  /// Attempts to clock in the employee identified by [employeeId].
  ///
  /// On [ClockInSuccess] the record is persisted immediately.
  /// On [ClockInRequiresPasswordSetup] the pending record is NOT persisted —
  /// call [completeClockInWithSetup] after the employee sets their password.
  Future<ClockInResult> clockIn(String employeeId, String password) async {
    final employee = await _db.getEmployeeById(employeeId);
    if (employee == null) return const ClockInWrongPassword();

    final today = DateTime.now();
    final existing =
        await _db.getEmployeeAttendanceForDate(employeeId, today);

    final result = buildClockInResult(
      employee: employee,
      password: password,
      existingRecord: existing,
      now: today,
    );

    if (result is ClockInSuccess) {
      await _db.insertAttendanceRecord(result.record);
      _firestore?.upsertAttendanceRecord(result.record);
    }

    return result;
  }

  /// Called after the mandatory first-time [SetPasswordModal] completes.
  ///
  /// Atomically (from the user's perspective):
  ///   1. Hashes [newPassword] and saves it to the employee record.
  ///   2. Clears the [Employee.isDefaultPassword] flag.
  ///   3. Persists the [pendingRecord] clock-in.
  ///   4. Syncs both to Firestore (fire-and-forget).
  ///
  /// Throws [ArgumentError] if [newPassword] fails the length check — this
  /// should be impossible in practice because the modal validates before
  /// calling this method.
  Future<ClockInResult> completeClockInWithSetup({
    required Employee employee,
    required AttendanceRecord pendingRecord,
    required String newPassword,
  }) async {
    if (!PasswordUtils.isValidLength(newPassword)) {
      throw ArgumentError(
        'New password must be ${PasswordUtils.minPasswordLength}'
        '–${PasswordUtils.maxPasswordLength} characters.',
      );
    }

    final updatedEmployee = employee.copyWith(
      passwordHash: PasswordUtils.hashPassword(newPassword),
      isDefaultPassword: false,
    );

    await _db.updateEmployee(updatedEmployee);
    await _db.insertAttendanceRecord(pendingRecord);
    _firestore?.upsertEmployee(updatedEmployee);
    _firestore?.upsertAttendanceRecord(pendingRecord);

    return ClockInSuccess(pendingRecord);
  }

  /// Attempts to clock out the employee identified by [employeeId].
  ///
  /// On [ClockOutSuccess] the record is updated in SQLite and synced to
  /// Firestore.  All other results leave the database unchanged.
  Future<ClockOutResult> clockOut(String employeeId, String password) async {
    final employee = await _db.getEmployeeById(employeeId);
    if (employee == null) return const ClockOutWrongPassword();

    final today = DateTime.now();
    final record = await _db.getEmployeeAttendanceForDate(employeeId, today);

    // Defensive guard: if the employee has no open record the UI should never
    // have offered them a clock-out tap, but we handle it gracefully.
    if (record == null) return const ClockOutWrongPassword();

    final result = buildClockOutResult(
      employee: employee,
      record: record,
      password: password,
      now: today,
    );

    if (result is ClockOutSuccess) {
      await _db.updateAttendanceRecord(result.record);
      _firestore?.upsertAttendanceRecord(result.record);
    }

    return result;
  }

  /// Authenticates an admin by [username] and [password].
  ///
  /// Returns [AdminLoginSuccess] with the [AdminUser] on success, or
  /// [AdminLoginFailure] for any failure (unknown username or wrong password).
  Future<AdminLoginResult> loginAdmin(
      String username, String password) async {
    final admin = await _db.getAdminByUsername(username);
    return buildAdminLoginResult(admin: admin, password: password);
  }
}
