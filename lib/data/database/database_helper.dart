import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';

/// Singleton SQLite helper.
///
/// All on-device persistence goes through this class. The database is the
/// source of truth when the device is offline; Firestore acts as the cloud
/// backup and is synced separately via [FirestoreService].
///
/// Schema version history:
///   v1 — initial schema (Phase 1)
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'wellness_on_wellington.db';
  static const _dbVersion = 1;

  // Table names — referenced by both this file and FirestoreService.
  static const tableEmployees = 'employees';
  static const tableAttendanceRecords = 'attendance_records';
  static const tableAdminUsers = 'admin_users';
  static const tablePublicHolidays = 'public_holidays';

  Database? _db;

  Future<Database> get database async {
    _db ??= await _openDatabase();
    return _db!;
  }

  Future<Database> _openDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
    );
  }

  /// Enable foreign key constraints (disabled by default in SQLite).
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── employees ──────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE $tableEmployees (
        id                   TEXT PRIMARY KEY,
        name                 TEXT NOT NULL,
        password_hash        TEXT NOT NULL,
        is_default_password  INTEGER NOT NULL DEFAULT 1,
        created_at           TEXT NOT NULL
      )
    ''');

    // ── attendance_records ─────────────────────────────────────────────────
    // clock_out_time and total_hours are nullable (null = not yet clocked out)
    await db.execute('''
      CREATE TABLE $tableAttendanceRecords (
        id             TEXT PRIMARY KEY,
        employee_id    TEXT NOT NULL,
        employee_name  TEXT NOT NULL,
        date           TEXT NOT NULL,
        clock_in_time  TEXT NOT NULL,
        clock_out_time TEXT,
        status         TEXT NOT NULL,
        total_hours    REAL,
        FOREIGN KEY (employee_id) REFERENCES $tableEmployees (id)
          ON DELETE CASCADE
      )
    ''');

    // ── admin_users ────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE $tableAdminUsers (
        id             TEXT PRIMARY KEY,
        username       TEXT NOT NULL UNIQUE,
        password_hash  TEXT NOT NULL
      )
    ''');

    // ── public_holidays ────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE $tablePublicHolidays (
        id    TEXT PRIMARY KEY,
        date  TEXT NOT NULL UNIQUE,
        name  TEXT NOT NULL
      )
    ''');

    // ── Indexes for common query patterns ──────────────────────────────────
    await db.execute(
      'CREATE INDEX idx_attendance_date '
      'ON $tableAttendanceRecords (date)',
    );
    await db.execute(
      'CREATE INDEX idx_attendance_employee_date '
      'ON $tableAttendanceRecords (employee_id, date)',
    );
    await db.execute(
      'CREATE INDEX idx_employee_name '
      'ON $tableEmployees (name COLLATE NOCASE)',
    );

    debugPrint('[DB] Schema v$version created.');
  }

  // ── Employee CRUD ────────────────────────────────────────────────────────

  Future<void> insertEmployee(Employee employee) async {
    final db = await database;
    await db.insert(
      tableEmployees,
      employee.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Employee?> getEmployeeById(String id) async {
    final db = await database;
    final rows = await db.query(
      tableEmployees,
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : Employee.fromMap(rows.first);
  }

  Future<List<Employee>> getAllEmployees() async {
    final db = await database;
    final rows = await db.query(tableEmployees, orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Employee.fromMap).toList();
  }

  Future<void> updateEmployee(Employee employee) async {
    final db = await database;
    await db.update(
      tableEmployees,
      employee.toMap(),
      where: 'id = ?',
      whereArgs: [employee.id],
    );
  }

  Future<void> deleteEmployee(String id) async {
    final db = await database;
    await db.delete(tableEmployees, where: 'id = ?', whereArgs: [id]);
  }

  // ── AttendanceRecord CRUD ────────────────────────────────────────────────

  Future<void> insertAttendanceRecord(AttendanceRecord record) async {
    final db = await database;
    await db.insert(
      tableAttendanceRecords,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AttendanceRecord?> getAttendanceRecordById(String id) async {
    final db = await database;
    final rows = await db.query(
      tableAttendanceRecords,
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : AttendanceRecord.fromMap(rows.first);
  }

  /// All records for a given calendar date, sorted by clock-in time.
  Future<List<AttendanceRecord>> getAttendanceForDate(DateTime date) async {
    final db = await database;
    final dateKey = _dateKey(date);
    final rows = await db.query(
      tableAttendanceRecords,
      where: 'date = ?',
      whereArgs: [dateKey],
      orderBy: 'clock_in_time ASC',
    );
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  /// The single attendance record for one employee on a specific date,
  /// or null if the employee has not clocked in that day.
  Future<AttendanceRecord?> getEmployeeAttendanceForDate(
    String employeeId,
    DateTime date,
  ) async {
    final db = await database;
    final rows = await db.query(
      tableAttendanceRecords,
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, _dateKey(date)],
    );
    return rows.isEmpty ? null : AttendanceRecord.fromMap(rows.first);
  }

  Future<void> updateAttendanceRecord(AttendanceRecord record) async {
    final db = await database;
    await db.update(
      tableAttendanceRecords,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // ── AdminUser CRUD ───────────────────────────────────────────────────────

  Future<void> insertAdminUser(AdminUser admin) async {
    final db = await database;
    await db.insert(
      tableAdminUsers,
      admin.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AdminUser?> getAdminByUsername(String username) async {
    final db = await database;
    final rows = await db.query(
      tableAdminUsers,
      where: 'username = ?',
      whereArgs: [username],
    );
    return rows.isEmpty ? null : AdminUser.fromMap(rows.first);
  }

  Future<List<AdminUser>> getAllAdmins() async {
    final db = await database;
    final rows = await db.query(tableAdminUsers);
    return rows.map(AdminUser.fromMap).toList();
  }

  Future<void> updateAdminUser(AdminUser admin) async {
    final db = await database;
    await db.update(
      tableAdminUsers,
      admin.toMap(),
      where: 'id = ?',
      whereArgs: [admin.id],
    );
  }

  // ── PublicHoliday CRUD ───────────────────────────────────────────────────

  Future<void> insertPublicHoliday(PublicHoliday holiday) async {
    final db = await database;
    await db.insert(
      tablePublicHolidays,
      holiday.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PublicHoliday>> getAllPublicHolidays() async {
    final db = await database;
    final rows = await db.query(tablePublicHolidays, orderBy: 'date ASC');
    return rows.map(PublicHoliday.fromMap).toList();
  }

  Future<bool> isPublicHoliday(DateTime date) async {
    final db = await database;
    final rows = await db.query(
      tablePublicHolidays,
      where: 'date = ?',
      whereArgs: [_dateKey(date)],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> deletePublicHoliday(String id) async {
    final db = await database;
    await db.delete(tablePublicHolidays, where: 'id = ?', whereArgs: [id]);
  }

  // ── Utility ──────────────────────────────────────────────────────────────

  /// YYYY-MM-DD date key — shared format between SQLite and Firestore.
  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
