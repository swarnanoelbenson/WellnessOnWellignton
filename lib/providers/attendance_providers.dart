import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database_helper.dart';
import '../models/models.dart';

/// Three-bucket grouping of employees for today's attendance board.
class AttendanceBoardState {
  const AttendanceBoardState({
    required this.notClockedIn,
    required this.clockedIn,
    required this.completed,
  });

  /// Employees with no attendance record today.
  final List<Employee> notClockedIn;

  /// Employees currently clocked in (record exists, no clock-out time).
  final List<AttendanceRecord> clockedIn;

  /// Employees who have completed their shift today.
  final List<AttendanceRecord> completed;
}

// ── Raw data providers ────────────────────────────────────────────────────────

/// All employees, sorted alphabetically by name.
/// Invalidate after any employee mutation (e.g. password setup).
final employeesProvider = FutureProvider<List<Employee>>((ref) {
  return DatabaseHelper.instance.getAllEmployees();
});

/// All attendance records for today's date.
/// Invalidate after any clock-in / clock-out mutation.
final todayAttendanceProvider = FutureProvider<List<AttendanceRecord>>((ref) {
  return DatabaseHelper.instance.getAttendanceForDate(DateTime.now());
});

// ── Computed board state ──────────────────────────────────────────────────────

/// Combines [employeesProvider] and [todayAttendanceProvider] into a
/// ready-to-render [AttendanceBoardState].
///
/// Returns [AsyncValue.loading] while either upstream provider is loading.
final attendanceBoardProvider =
    Provider<AsyncValue<AttendanceBoardState>>((ref) {
  final employeesAsync = ref.watch(employeesProvider);
  final attendanceAsync = ref.watch(todayAttendanceProvider);

  if (employeesAsync.isLoading || attendanceAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (employeesAsync.hasError) {
    return AsyncValue.error(
      employeesAsync.error!,
      employeesAsync.stackTrace!,
    );
  }

  if (attendanceAsync.hasError) {
    return AsyncValue.error(
      attendanceAsync.error!,
      attendanceAsync.stackTrace!,
    );
  }

  final employees = employeesAsync.requireValue;
  final records = attendanceAsync.requireValue;

  // Build a lookup: employeeId → today's record.
  final recordMap = {for (final r in records) r.employeeId: r};

  final notClockedIn = <Employee>[];
  final clockedIn = <AttendanceRecord>[];
  final completed = <AttendanceRecord>[];

  for (final emp in employees) {
    final record = recordMap[emp.id];
    if (record == null) {
      notClockedIn.add(emp);
    } else if (record.clockOutTime == null) {
      clockedIn.add(record);
    } else {
      completed.add(record);
    }
  }

  return AsyncValue.data(AttendanceBoardState(
    notClockedIn: notClockedIn,
    clockedIn: clockedIn,
    completed: completed,
  ));
});
