import 'package:csv/csv.dart';

import '../data/database/database_helper.dart';
import '../data/firebase/firestore_service.dart';
import '../models/models.dart';
import '../utils/password_utils.dart';

/// Admin operations: employee management, public holidays, and CSV generation.
///
/// Mirrors [AuthService]'s design — all mutations write to SQLite first, then
/// fire-and-forget to Firestore when it is available.
class AdminService {
  AdminService({required DatabaseHelper db, FirestoreService? firestore})
      : _db = db,
        _firestore = firestore;

  final DatabaseHelper _db;
  final FirestoreService? _firestore;

  // ── Employee management ───────────────────────────────────────────────────

  /// Creates a new employee with the default password and persists them.
  Future<void> addEmployee(String name) async {
    final hash = PasswordUtils.hashPassword(PasswordUtils.defaultPassword);
    final employee = Employee.create(
      name: name.trim(),
      defaultPasswordHash: hash,
    );
    await _db.insertEmployee(employee);
    _firestore?.upsertEmployee(employee);
  }

  /// Permanently deletes an employee and all their attendance records
  /// (cascade delete enforced by the SQLite foreign key).
  Future<void> removeEmployee(String id) async {
    await _db.deleteEmployee(id);
    _firestore?.deleteEmployee(id);
  }

  /// Resets an employee's password back to the system default and raises
  /// the [isDefaultPassword] flag so they are forced to set a new password
  /// on their next clock-in.
  Future<void> resetEmployeePassword(Employee employee) async {
    final hash = PasswordUtils.hashPassword(PasswordUtils.defaultPassword);
    final updated = employee.copyWith(
      passwordHash: hash,
      isDefaultPassword: true,
    );
    await _db.updateEmployee(updated);
    _firestore?.upsertEmployee(updated);
  }

  // ── Public holidays ───────────────────────────────────────────────────────

  Future<void> addPublicHoliday(DateTime date, String name) async {
    final holiday = PublicHoliday.create(date: date, name: name.trim());
    await _db.insertPublicHoliday(holiday);
    _firestore?.upsertPublicHoliday(holiday);
  }

  Future<void> removePublicHoliday(String id) async {
    await _db.deletePublicHoliday(id);
    _firestore?.deletePublicHoliday(id);
  }

  // ── Reports ───────────────────────────────────────────────────────────────

  Future<List<Employee>> getAllEmployees() => _db.getAllEmployees();

  Future<List<AttendanceRecord>> getAttendanceForDateRange(
    DateTime from,
    DateTime to,
  ) async {
    return _db.getAttendanceForDateRange(from, to);
  }

  /// Detailed CSV — one row per session per employee, with per-employee totals
  /// and a blank separator row between employees.
  ///
  /// Columns: Employee Name, Session, Clock-In, Clock-Out, Hours, Status
  ///
  /// Absent employees (no records in [records]) get a single "Absent" row.
  static String generateDetailedCsv(
    List<Employee> allEmployees,
    List<AttendanceRecord> records,
  ) {
    final rows = <List<dynamic>>[
      ['Employee Name', 'Session', 'Clock-In', 'Clock-Out', 'Hours', 'Status'],
    ];

    // Group records by employee.
    final byEmployee = <String, List<AttendanceRecord>>{};
    for (final r in records) {
      (byEmployee[r.employeeId] ??= []).add(r);
    }

    for (final emp in allEmployees) {
      final sessions = byEmployee[emp.id] ?? [];

      if (sessions.isEmpty) {
        rows.add([emp.name, '', '', '', '', 'Absent']);
      } else {
        sessions.sort((a, b) => a.clockInTime.compareTo(b.clockInTime));

        double totalHours = 0;
        bool hasMissing = false;

        for (int i = 0; i < sessions.length; i++) {
          final s = sessions[i];
          final String hoursStr;
          final String status;

          if (s.clockOutTime == null) {
            hasMissing = true;
            hoursStr = '';
            status = '⚠ Missing Clock-Out';
          } else {
            hoursStr = s.totalHours?.toStringAsFixed(2) ?? '';
            totalHours += s.totalHours ?? 0;
            status = 'Complete';
          }

          rows.add([
            emp.name,
            'Session ${i + 1}',
            _fmt(s.clockInTime),
            s.clockOutTime != null ? _fmt(s.clockOutTime!) : '',
            hoursStr,
            status,
          ]);
        }

        // Summary row for this employee.
        rows.add([
          '${emp.name} Total',
          '',
          '',
          '',
          hasMissing ? '' : totalHours.toStringAsFixed(2),
          '',
        ]);
      }

      // Blank separator between employees.
      rows.add(['', '', '', '', '', '']);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Summary CSV — one row per employee, total hours across all sessions.
  ///
  /// Columns: Employee Name, Total Hours, Status
  ///
  /// If any session has a missing clock-out, Total Hours is blank and
  /// Status is "⚠ Missing Clock-Out". Absent employees get a single row
  /// with status "Absent".
  static String generateSummaryCsv(
    List<Employee> allEmployees,
    List<AttendanceRecord> records,
  ) {
    final rows = <List<dynamic>>[
      ['Employee Name', 'Total Hours', 'Status'],
    ];

    final byEmployee = <String, List<AttendanceRecord>>{};
    for (final r in records) {
      (byEmployee[r.employeeId] ??= []).add(r);
    }

    for (final emp in allEmployees) {
      final sessions = byEmployee[emp.id] ?? [];

      if (sessions.isEmpty) {
        rows.add([emp.name, '', 'Absent']);
      } else if (sessions.any((s) => s.clockOutTime == null)) {
        rows.add([emp.name, '', '⚠ Missing Clock-Out']);
      } else {
        final total = sessions.fold(0.0, (sum, s) => sum + (s.totalHours ?? 0));
        rows.add([emp.name, total.toStringAsFixed(2), 'Complete']);
      }
    }

    return const ListToCsvConverter().convert(rows);
  }

  static String _fmt(DateTime dt) {
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$h:$mm $period';
  }
}
