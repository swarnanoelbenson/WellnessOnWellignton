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

  Future<List<AttendanceRecord>> getAttendanceForDateRange(
    DateTime from,
    DateTime to,
  ) async {
    return _db.getAttendanceForDateRange(from, to);
  }

  /// Converts a list of attendance records to a RFC-4180 CSV string.
  ///
  /// Columns: Employee Name, Date, Clock In, Clock Out, Total Hours, Status
  static String generateCsv(List<AttendanceRecord> records) {
    final rows = <List<dynamic>>[
      ['Employee Name', 'Date', 'Clock In', 'Clock Out', 'Total Hours', 'Status'],
      for (final r in records)
        [
          r.employeeName,
          r.dateKey,
          _fmt(r.clockInTime),
          r.clockOutTime != null ? _fmt(r.clockOutTime!) : '',
          r.totalHours?.toStringAsFixed(2) ?? '',
          r.status.displayLabel,
        ],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  static String _fmt(DateTime dt) {
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$h:$mm $period';
  }
}
