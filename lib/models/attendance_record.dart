import 'package:uuid/uuid.dart';

/// The final status of an attendance record — used in the CSV export.
enum AttendanceStatus {
  complete,
  absent,
  missingClockOut;

  /// Human-readable label used in the CSV "Status" column.
  String get displayLabel {
    switch (this) {
      case AttendanceStatus.complete:
        return 'Complete';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.missingClockOut:
        return '⚠ Missing Clock-Out';
    }
  }

  /// Compact snake_case value stored in SQLite and Firestore.
  String get storageKey {
    switch (this) {
      case AttendanceStatus.complete:
        return 'complete';
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.missingClockOut:
        return 'missing_clock_out';
    }
  }

  static AttendanceStatus fromStorageKey(String key) {
    switch (key) {
      case 'complete':
        return AttendanceStatus.complete;
      case 'absent':
        return AttendanceStatus.absent;
      case 'missing_clock_out':
        return AttendanceStatus.missingClockOut;
      default:
        throw ArgumentError('Unknown AttendanceStatus key: "$key"');
    }
  }
}

/// A single day's clock-in / clock-out record for one employee.
///
/// A record is created the moment the employee clocks in. The [clockOutTime]
/// and [totalHours] fields are null until the employee clocks out.
/// [status] defaults to [AttendanceStatus.missingClockOut] on creation and
/// is updated to [AttendanceStatus.complete] when the employee clocks out.
class AttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName; // denormalised for easy CSV generation
  final DateTime date;       // midnight — date portion only
  final DateTime clockInTime;
  final DateTime? clockOutTime;
  final AttendanceStatus status;
  final double? totalHours; // decimal hours, e.g. 8.5 = 8h 30m

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.clockInTime,
    this.clockOutTime,
    required this.status,
    this.totalHours,
  });

  /// Creates a new clock-in record. Status is set to [missingClockOut]
  /// until the employee clocks out via [withClockOut].
  factory AttendanceRecord.clockIn({
    required String employeeId,
    required String employeeName,
    required DateTime clockInTime,
  }) {
    return AttendanceRecord(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      date: DateTime(clockInTime.year, clockInTime.month, clockInTime.day),
      clockInTime: clockInTime,
      status: AttendanceStatus.missingClockOut,
    );
  }

  /// Returns a copy of this record with [clockOutTime] and [totalHours] set
  /// and [status] updated to [AttendanceStatus.complete].
  AttendanceRecord withClockOut(DateTime clockOutTime) {
    final hours =
        clockOutTime.difference(clockInTime).inSeconds / 3600.0;
    return AttendanceRecord(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      clockInTime: clockInTime,
      clockOutTime: clockOutTime,
      status: AttendanceStatus.complete,
      totalHours: double.parse(hours.toStringAsFixed(2)),
    );
  }

  AttendanceRecord copyWith({
    DateTime? clockOutTime,
    AttendanceStatus? status,
    double? totalHours,
  }) {
    return AttendanceRecord(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      clockInTime: clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      status: status ?? this.status,
      totalHours: totalHours ?? this.totalHours,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// YYYY-MM-DD string used as the date key in both SQLite and Firestore.
  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ── SQLite serialisation ────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'date': dateKey,
      'clock_in_time': clockInTime.toIso8601String(),
      'clock_out_time': clockOutTime?.toIso8601String(),
      'status': status.storageKey,
      'total_hours': totalHours,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      employeeName: map['employee_name'] as String,
      date: DateTime.parse(map['date'] as String),
      clockInTime: DateTime.parse(map['clock_in_time'] as String),
      clockOutTime: map['clock_out_time'] != null
          ? DateTime.parse(map['clock_out_time'] as String)
          : null,
      status: AttendanceStatus.fromStorageKey(map['status'] as String),
      totalHours: (map['total_hours'] as num?)?.toDouble(),
    );
  }

  // ── Firestore serialisation ─────────────────────────────────────────────

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'date': dateKey,
      'clock_in_time': clockInTime.toIso8601String(),
      'clock_out_time': clockOutTime?.toIso8601String(),
      'status': status.storageKey,
      'total_hours': totalHours,
    };
  }

  factory AttendanceRecord.fromFirestoreMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      employeeName: map['employee_name'] as String,
      date: DateTime.parse(map['date'] as String),
      clockInTime: DateTime.parse(map['clock_in_time'] as String),
      clockOutTime: map['clock_out_time'] != null
          ? DateTime.parse(map['clock_out_time'] as String)
          : null,
      status: AttendanceStatus.fromStorageKey(map['status'] as String),
      totalHours: (map['total_hours'] as num?)?.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AttendanceRecord && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AttendanceRecord(id: $id, employee: $employeeName, date: $dateKey, status: ${status.storageKey})';
}
