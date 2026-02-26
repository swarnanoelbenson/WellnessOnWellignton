// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';

import 'package:wellness_on_wellington/models/admin_user.dart';
import 'package:wellness_on_wellington/models/attendance_record.dart';
import 'package:wellness_on_wellington/models/auth_result.dart';
import 'package:wellness_on_wellington/models/employee.dart';
import 'package:wellness_on_wellington/services/auth_service.dart';
import 'package:wellness_on_wellington/utils/password_utils.dart';

// ---------------------------------------------------------------------------
// Test fixtures
//
// bcrypt is intentionally slow.  We hash once per suite (setUpAll) and
// reuse the resulting hashes across all tests.
// ---------------------------------------------------------------------------

late String _correctHash;       // hash of 'secret7'
late String _defaultHash;       // hash of '123456'
late String _adminHash;         // hash of 'AdminP1'

const String _correctPassword = 'secret7';
const String _wrongPassword   = 'wrong99';
const String _adminPassword   = 'AdminP1';

/// A regular employee with a personal password.
Employee _regularEmployee() => Employee(
      id: 'emp-regular',
      name: 'Alice',
      passwordHash: _correctHash,
      isDefaultPassword: false,
      createdAt: DateTime(2024, 1, 1),
    );

/// A new employee who has never logged in (still has the default password).
Employee _firstTimeEmployee() => Employee(
      id: 'emp-first',
      name: 'Bob',
      passwordHash: _defaultHash,
      isDefaultPassword: true,
      createdAt: DateTime(2024, 1, 1),
    );

/// An open (not yet clocked-out) attendance record for today.
AttendanceRecord _openRecord(Employee e, DateTime clockIn) =>
    AttendanceRecord.clockIn(
      employeeId: e.id,
      employeeName: e.name,
      clockInTime: clockIn,
    );

/// A completed attendance record (already clocked out).
AttendanceRecord _completedRecord(Employee e, DateTime clockIn) =>
    _openRecord(e, clockIn).withClockOut(clockIn.add(const Duration(hours: 8)));

AdminUser _admin() => AdminUser(
      id: 'admin-1',
      username: 'manager',
      passwordHash: _adminHash,
    );

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    // Hash once — bcrypt is slow.
    _correctHash = PasswordUtils.hashPassword(_correctPassword);
    _defaultHash = PasswordUtils.hashPassword(PasswordUtils.defaultPassword);
    _adminHash   = PasswordUtils.hashPassword(_adminPassword);
  });

  // ── PasswordUtils ────────────────────────────────────────────────────────

  group('PasswordUtils', () {
    test('hashPassword returns a non-empty string starting with \$2', () {
      final hash = PasswordUtils.hashPassword('myPass1');
      expect(hash, isNotEmpty);
      expect(hash, startsWith(r'$2'));
    });

    test('verifyPassword returns true for correct password', () {
      final hash = PasswordUtils.hashPassword('myPass1');
      expect(PasswordUtils.verifyPassword('myPass1', hash), isTrue);
    });

    test('verifyPassword returns false for wrong password', () {
      final hash = PasswordUtils.hashPassword('myPass1');
      expect(PasswordUtils.verifyPassword('wrong99', hash), isFalse);
    });

    test('two hashes of the same password are different (different salts)', () {
      final h1 = PasswordUtils.hashPassword('myPass1');
      final h2 = PasswordUtils.hashPassword('myPass1');
      expect(h1, isNot(equals(h2)));
    });

    test('isValidLength accepts passwords in range', () {
      expect(PasswordUtils.isValidLength('sixchr'), isTrue);   // 6
      expect(PasswordUtils.isValidLength('twelvecharsX'), isTrue); // 12
      expect(PasswordUtils.isValidLength('midlen99'), isTrue);  // 8
    });

    test('isValidLength rejects passwords out of range', () {
      expect(PasswordUtils.isValidLength('short'), isFalse);   // 5
      expect(PasswordUtils.isValidLength('thirteencharXX'), isFalse); // 13
      expect(PasswordUtils.isValidLength(''), isFalse);
    });

    test('defaultPassword is exactly "123456"', () {
      expect(PasswordUtils.defaultPassword, equals('123456'));
    });

    test('hashedDefaultPassword verifies against defaultPassword', () {
      final hash = PasswordUtils.hashedDefaultPassword;
      expect(PasswordUtils.verifyPassword(PasswordUtils.defaultPassword, hash),
          isTrue);
    });
  });

  // ── AuthService.verifyEmployeePassword ──────────────────────────────────

  group('AuthService.verifyEmployeePassword', () {
    test('returns true when password matches hash', () {
      final e = _regularEmployee();
      expect(AuthService.verifyEmployeePassword(e, _correctPassword), isTrue);
    });

    test('returns false when password does not match hash', () {
      final e = _regularEmployee();
      expect(
          AuthService.verifyEmployeePassword(e, _wrongPassword), isFalse);
    });

    test('returns true for first-time employee entering default password', () {
      final e = _firstTimeEmployee();
      expect(
        AuthService.verifyEmployeePassword(e, PasswordUtils.defaultPassword),
        isTrue,
      );
    });

    test('returns false for first-time employee entering wrong password', () {
      final e = _firstTimeEmployee();
      expect(
          AuthService.verifyEmployeePassword(e, _wrongPassword), isFalse);
    });
  });

  // ── AuthService.buildClockInResult ──────────────────────────────────────

  group('AuthService.buildClockInResult', () {
    final now = DateTime(2024, 6, 1, 9, 0);

    test('returns ClockInSuccess for correct password and no prior record', () {
      final result = AuthService.buildClockInResult(
        employee: _regularEmployee(),
        password: _correctPassword,
        existingRecord: null,
        now: now,
      );
      expect(result, isA<ClockInSuccess>());
      final success = result as ClockInSuccess;
      expect(success.record.employeeId, equals('emp-regular'));
      expect(success.record.clockInTime, equals(now));
      expect(success.record.clockOutTime, isNull);
      expect(success.record.status, equals(AttendanceStatus.missingClockOut));
    });

    test('returns ClockInWrongPassword for incorrect password', () {
      final result = AuthService.buildClockInResult(
        employee: _regularEmployee(),
        password: _wrongPassword,
        existingRecord: null,
        now: now,
      );
      expect(result, isA<ClockInWrongPassword>());
    });

    test('returns ClockInAlreadyClockedIn when open record exists', () {
      final e = _regularEmployee();
      final openRec = _openRecord(e, now.subtract(const Duration(hours: 1)));
      final result = AuthService.buildClockInResult(
        employee: e,
        password: _correctPassword,
        existingRecord: openRec,
        now: now,
      );
      expect(result, isA<ClockInAlreadyClockedIn>());
      final already = result as ClockInAlreadyClockedIn;
      expect(already.existing.id, equals(openRec.id));
    });

    test('AlreadyClockedIn check fires before password check', () {
      // Even with wrong password, if already clocked in we get AlreadyClockedIn.
      final e = _regularEmployee();
      final openRec = _openRecord(e, now);
      final result = AuthService.buildClockInResult(
        employee: e,
        password: _wrongPassword, // wrong, but shouldn't matter
        existingRecord: openRec,
        now: now,
      );
      expect(result, isA<ClockInAlreadyClockedIn>());
    });

    test('completed record does NOT block a new clock-in', () {
      // If the employee completed their shift, they should NOT appear as
      // "already clocked in" for a future (edge-case) same-day scenario.
      // The business logic: existingRecord.clockOutTime != null means
      // the guard is skipped and the employee can proceed normally.
      final e = _regularEmployee();
      final completed = _completedRecord(e, now.subtract(const Duration(hours: 9)));
      final result = AuthService.buildClockInResult(
        employee: e,
        password: _correctPassword,
        existingRecord: completed,
        now: now,
      );
      // Should NOT be AlreadyClockedIn because clockOutTime is set.
      expect(result, isNot(isA<ClockInAlreadyClockedIn>()));
    });

    test('first-time employee with default password → ClockInRequiresPasswordSetup',
        () {
      final e = _firstTimeEmployee();
      final result = AuthService.buildClockInResult(
        employee: e,
        password: PasswordUtils.defaultPassword,
        existingRecord: null,
        now: now,
      );
      expect(result, isA<ClockInRequiresPasswordSetup>());
      final setup = result as ClockInRequiresPasswordSetup;
      expect(setup.employee.id, equals(e.id));
      expect(setup.pendingRecord.clockInTime, equals(now));
    });

    test('first-time employee with wrong password → ClockInWrongPassword', () {
      final e = _firstTimeEmployee();
      final result = AuthService.buildClockInResult(
        employee: e,
        password: _wrongPassword,
        existingRecord: null,
        now: now,
      );
      expect(result, isA<ClockInWrongPassword>());
    });

    test('pending record in ClockInSuccess has no clock-out time', () {
      final result = AuthService.buildClockInResult(
        employee: _regularEmployee(),
        password: _correctPassword,
        existingRecord: null,
        now: now,
      );
      final success = result as ClockInSuccess;
      expect(success.record.clockOutTime, isNull);
      expect(success.record.totalHours, isNull);
    });
  });

  // ── AuthService.buildClockOutResult ─────────────────────────────────────

  group('AuthService.buildClockOutResult', () {
    final clockIn = DateTime(2024, 6, 1, 9, 0);
    final clockOut = DateTime(2024, 6, 1, 17, 30); // 8.5 hours later

    test('returns ClockOutSuccess with updated record on correct password', () {
      final e = _regularEmployee();
      final openRec = _openRecord(e, clockIn);
      final result = AuthService.buildClockOutResult(
        employee: e,
        record: openRec,
        password: _correctPassword,
        now: clockOut,
      );
      expect(result, isA<ClockOutSuccess>());
      final success = result as ClockOutSuccess;
      expect(success.record.clockOutTime, equals(clockOut));
      expect(success.record.status, equals(AttendanceStatus.complete));
      expect(success.record.totalHours, closeTo(8.5, 0.01));
    });

    test('totalHours is calculated correctly for a shift', () {
      final e = _regularEmployee();
      final openRec = _openRecord(e, clockIn);
      // 13:15 - 09:00 = 4h 15m = 4.25 hours
      final endTime = DateTime(2024, 6, 1, 13, 15);
      final result = AuthService.buildClockOutResult(
        employee: e,
        record: openRec,
        password: _correctPassword,
        now: endTime,
      ) as ClockOutSuccess;
      expect(result.record.totalHours, closeTo(4.25, 0.01));
    });

    test('returns ClockOutWrongPassword for incorrect password', () {
      final e = _regularEmployee();
      final openRec = _openRecord(e, clockIn);
      final result = AuthService.buildClockOutResult(
        employee: e,
        record: openRec,
        password: _wrongPassword,
        now: clockOut,
      );
      expect(result, isA<ClockOutWrongPassword>());
    });

    test('returns ClockOutAlreadyCompleted if record already has clock-out', () {
      final e = _regularEmployee();
      final completedRec = _completedRecord(e, clockIn);
      // Even with correct password, cannot clock out again.
      final result = AuthService.buildClockOutResult(
        employee: e,
        record: completedRec,
        password: _correctPassword,
        now: clockOut,
      );
      expect(result, isA<ClockOutAlreadyCompleted>());
    });

    test('AlreadyCompleted check fires before password check', () {
      final e = _regularEmployee();
      final completedRec = _completedRecord(e, clockIn);
      final result = AuthService.buildClockOutResult(
        employee: e,
        record: completedRec,
        password: _wrongPassword, // wrong — but shouldn't matter
        now: clockOut,
      );
      expect(result, isA<ClockOutAlreadyCompleted>());
    });

    test('ClockOutSuccess record retains original clock-in time', () {
      final e = _regularEmployee();
      final openRec = _openRecord(e, clockIn);
      final result = AuthService.buildClockOutResult(
        employee: e,
        record: openRec,
        password: _correctPassword,
        now: clockOut,
      ) as ClockOutSuccess;
      expect(result.record.clockInTime, equals(clockIn));
    });

    test('ClockOutSuccess record retains employee id and name', () {
      final e = _regularEmployee();
      final openRec = _openRecord(e, clockIn);
      final result = AuthService.buildClockOutResult(
        employee: e,
        record: openRec,
        password: _correctPassword,
        now: clockOut,
      ) as ClockOutSuccess;
      expect(result.record.employeeId, equals(e.id));
      expect(result.record.employeeName, equals(e.name));
    });
  });

  // ── AuthService.buildAdminLoginResult ───────────────────────────────────

  group('AuthService.buildAdminLoginResult', () {
    test('returns AdminLoginSuccess for correct username and password', () {
      final result = AuthService.buildAdminLoginResult(
        admin: _admin(),
        password: _adminPassword,
      );
      expect(result, isA<AdminLoginSuccess>());
      final success = result as AdminLoginSuccess;
      expect(success.admin.username, equals('manager'));
    });

    test('returns AdminLoginFailure for wrong password', () {
      final result = AuthService.buildAdminLoginResult(
        admin: _admin(),
        password: _wrongPassword,
      );
      expect(result, isA<AdminLoginFailure>());
    });

    test('returns AdminLoginFailure when admin is null (unknown username)', () {
      final result = AuthService.buildAdminLoginResult(
        admin: null,
        password: _adminPassword,
      );
      expect(result, isA<AdminLoginFailure>());
    });

    test('AdminLoginFailure exposes no detail (constant, no fields)', () {
      final result = AuthService.buildAdminLoginResult(
        admin: null,
        password: _wrongPassword,
      );
      // Both wrong-username and wrong-password produce the same type —
      // no way to distinguish them from the outside.
      expect(result.runtimeType, equals(AdminLoginFailure));
    });
  });

  // ── AttendanceRecord helpers ─────────────────────────────────────────────

  group('AttendanceRecord', () {
    final clockIn = DateTime(2024, 6, 1, 8, 0);

    test('clockIn factory sets status to missingClockOut', () {
      final e = _regularEmployee();
      final rec = AttendanceRecord.clockIn(
        employeeId: e.id,
        employeeName: e.name,
        clockInTime: clockIn,
      );
      expect(rec.status, equals(AttendanceStatus.missingClockOut));
      expect(rec.clockOutTime, isNull);
      expect(rec.totalHours, isNull);
    });

    test('withClockOut sets status to complete', () {
      final e = _regularEmployee();
      final rec = AttendanceRecord.clockIn(
        employeeId: e.id,
        employeeName: e.name,
        clockInTime: clockIn,
      ).withClockOut(clockIn.add(const Duration(hours: 9)));
      expect(rec.status, equals(AttendanceStatus.complete));
      expect(rec.clockOutTime, isNotNull);
      expect(rec.totalHours, closeTo(9.0, 0.01));
    });

    test('dateKey is YYYY-MM-DD formatted', () {
      final e = _regularEmployee();
      final rec = AttendanceRecord.clockIn(
        employeeId: e.id,
        employeeName: e.name,
        clockInTime: DateTime(2024, 3, 5, 9, 0),
      );
      expect(rec.dateKey, equals('2024-03-05'));
    });

    test('withClockOut preserves id, employeeId, employeeName, clockInTime',
        () {
      final e = _regularEmployee();
      final original = AttendanceRecord.clockIn(
        employeeId: e.id,
        employeeName: e.name,
        clockInTime: clockIn,
      );
      final completed =
          original.withClockOut(clockIn.add(const Duration(hours: 8)));
      expect(completed.id, equals(original.id));
      expect(completed.employeeId, equals(original.employeeId));
      expect(completed.employeeName, equals(original.employeeName));
      expect(completed.clockInTime, equals(original.clockInTime));
    });

    test('SQLite round-trip (toMap → fromMap) preserves all fields', () {
      final e = _regularEmployee();
      final original = AttendanceRecord.clockIn(
        employeeId: e.id,
        employeeName: e.name,
        clockInTime: clockIn,
      ).withClockOut(clockIn.add(const Duration(hours: 7, minutes: 45)));

      final restored = AttendanceRecord.fromMap(original.toMap());
      expect(restored.id, equals(original.id));
      expect(restored.employeeId, equals(original.employeeId));
      expect(restored.employeeName, equals(original.employeeName));
      expect(restored.clockInTime.toIso8601String(),
          equals(original.clockInTime.toIso8601String()));
      expect(restored.clockOutTime?.toIso8601String(),
          equals(original.clockOutTime?.toIso8601String()));
      expect(restored.status, equals(original.status));
      expect(restored.totalHours, closeTo(original.totalHours!, 0.001));
    });
  });

  // ── Employee model ───────────────────────────────────────────────────────

  group('Employee', () {
    test('SQLite round-trip (toMap → fromMap) preserves isDefaultPassword',
        () {
      final e = _firstTimeEmployee();
      final restored = Employee.fromMap(e.toMap());
      expect(restored.isDefaultPassword, isTrue);
    });

    test('copyWith can clear isDefaultPassword flag', () {
      final e = _firstTimeEmployee();
      final updated = e.copyWith(
        passwordHash: _correctHash,
        isDefaultPassword: false,
      );
      expect(updated.isDefaultPassword, isFalse);
      expect(updated.id, equals(e.id)); // id preserved
      expect(updated.name, equals(e.name)); // name preserved
    });

    test('SQLite int encoding: isDefaultPassword=true → 1, false → 0', () {
      final trueMap  = _firstTimeEmployee().toMap();
      final falseMap = _regularEmployee().toMap();
      expect(trueMap['is_default_password'],  equals(1));
      expect(falseMap['is_default_password'], equals(0));
    });
  });

  // ── AttendanceStatus enum ────────────────────────────────────────────────

  group('AttendanceStatus', () {
    test('storage keys round-trip correctly', () {
      for (final status in AttendanceStatus.values) {
        final restored = AttendanceStatus.fromStorageKey(status.storageKey);
        expect(restored, equals(status));
      }
    });

    test('displayLabel for missingClockOut contains warning symbol', () {
      expect(AttendanceStatus.missingClockOut.displayLabel, contains('⚠'));
    });

    test('fromStorageKey throws on unknown key', () {
      expect(
        () => AttendanceStatus.fromStorageKey('bogus'),
        throwsArgumentError,
      );
    });
  });
}
