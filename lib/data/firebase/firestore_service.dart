import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/models.dart';

/// Cloud sync layer — mirrors the local SQLite database in Firestore.
///
/// Collection layout:
///   /employees/{id}           — Employee documents
///   /attendance_records/{id}  — AttendanceRecord documents
///   /admin_users/{id}         — AdminUser documents (restricted read/write)
///   /public_holidays/{id}     — PublicHoliday documents
///
/// All writes are upserts (set with merge = false) keyed on the model's UUID.
/// Reads return typed model objects via the fromFirestoreMap factories.
///
/// Firebase Security Rules (to be deployed separately) must:
///   - Allow employees read on /employees (names only — no password_hash leak)
///   - Restrict /admin_users to authenticated admin UIDs only
///   - Allow employees write on their own /attendance_records document
///   - Require auth for all write operations
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // Collection name constants — keep in sync with DatabaseHelper.
  static const _colEmployees = 'employees';
  static const _colAttendance = 'attendance_records';
  static const _colAdmins = 'admin_users';
  static const _colHolidays = 'public_holidays';

  // ── Employees ────────────────────────────────────────────────────────────

  Future<void> upsertEmployee(Employee employee) async {
    await _safeWrite(
      () => _db
          .collection(_colEmployees)
          .doc(employee.id)
          .set(employee.toFirestoreMap()),
      label: 'upsertEmployee(${employee.id})',
    );
  }

  Future<void> deleteEmployee(String id) async {
    await _safeWrite(
      () => _db.collection(_colEmployees).doc(id).delete(),
      label: 'deleteEmployee($id)',
    );
  }

  /// Real-time stream of all employees, sorted by name.
  Stream<List<Employee>> watchEmployees() {
    return _db
        .collection(_colEmployees)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Employee.fromFirestoreMap(doc.data()))
            .toList());
  }

  Future<List<Employee>> fetchAllEmployees() async {
    final snap =
        await _db.collection(_colEmployees).orderBy('name').get();
    return snap.docs
        .map((doc) => Employee.fromFirestoreMap(doc.data()))
        .toList();
  }

  // ── AttendanceRecords ────────────────────────────────────────────────────

  Future<void> upsertAttendanceRecord(AttendanceRecord record) async {
    await _safeWrite(
      () => _db
          .collection(_colAttendance)
          .doc(record.id)
          .set(record.toFirestoreMap()),
      label: 'upsertAttendanceRecord(${record.id})',
    );
  }

  /// Real-time stream of all records for a given date, sorted by clock-in.
  Stream<List<AttendanceRecord>> watchAttendanceForDate(DateTime date) {
    final dateKey = _dateKey(date);
    return _db
        .collection(_colAttendance)
        .where('date', isEqualTo: dateKey)
        .orderBy('clock_in_time')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AttendanceRecord.fromFirestoreMap(doc.data()))
            .toList());
  }

  Future<List<AttendanceRecord>> fetchAttendanceForDate(DateTime date) async {
    final dateKey = _dateKey(date);
    final snap = await _db
        .collection(_colAttendance)
        .where('date', isEqualTo: dateKey)
        .orderBy('clock_in_time')
        .get();
    return snap.docs
        .map((doc) => AttendanceRecord.fromFirestoreMap(doc.data()))
        .toList();
  }

  // ── AdminUsers ───────────────────────────────────────────────────────────

  Future<void> upsertAdminUser(AdminUser admin) async {
    await _safeWrite(
      () => _db
          .collection(_colAdmins)
          .doc(admin.id)
          .set(admin.toFirestoreMap()),
      label: 'upsertAdminUser(${admin.id})',
    );
  }

  Future<void> updateAdminUser(AdminUser admin) => upsertAdminUser(admin);

  Future<List<AdminUser>> fetchAllAdmins() async {
    final snap = await _db.collection(_colAdmins).get();
    return snap.docs
        .map((doc) => AdminUser.fromFirestoreMap(doc.data()))
        .toList();
  }

  // ── PublicHolidays ───────────────────────────────────────────────────────

  Future<void> upsertPublicHoliday(PublicHoliday holiday) async {
    await _safeWrite(
      () => _db
          .collection(_colHolidays)
          .doc(holiday.id)
          .set(holiday.toFirestoreMap()),
      label: 'upsertPublicHoliday(${holiday.id})',
    );
  }

  Future<void> deletePublicHoliday(String id) async {
    await _safeWrite(
      () => _db.collection(_colHolidays).doc(id).delete(),
      label: 'deletePublicHoliday($id)',
    );
  }

  /// Real-time stream of all public holidays, sorted by date.
  Stream<List<PublicHoliday>> watchPublicHolidays() {
    return _db
        .collection(_colHolidays)
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PublicHoliday.fromFirestoreMap(doc.data()))
            .toList());
  }

  Future<List<PublicHoliday>> fetchAllPublicHolidays() async {
    final snap =
        await _db.collection(_colHolidays).orderBy('date').get();
    return snap.docs
        .map((doc) => PublicHoliday.fromFirestoreMap(doc.data()))
        .toList();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// YYYY-MM-DD format — consistent with SQLite dateKey.
  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Wraps a Firestore write in error handling so one failed sync does not
  /// crash the app. Errors are logged; the caller remains unaware, allowing
  /// the local SQLite record to remain the source of truth.
  Future<void> _safeWrite(
    Future<void> Function() operation, {
    required String label,
  }) async {
    try {
      await operation();
    } on FirebaseException catch (e) {
      debugPrint('[Firestore] $label failed: ${e.code} — ${e.message}');
    } catch (e) {
      debugPrint('[Firestore] $label unexpected error: $e');
    }
  }
}
