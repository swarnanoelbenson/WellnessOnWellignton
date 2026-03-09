import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database_helper.dart';
import '../models/models.dart';
import '../services/board_reset_service.dart';

/// Two-bucket grouping of employees for today's attendance board.
///
/// An employee can have multiple clock-in/clock-out sessions per day.
/// They appear in [clockedIn] if they have an open session (no clock-out yet),
/// and in [notClockedIn] otherwise — regardless of how many prior sessions they
/// have already completed.
class AttendanceBoardState {
  const AttendanceBoardState({
    required this.notClockedIn,
    required this.clockedIn,
    required this.lastClockOutTimes,
  });

  /// Employees with no currently-open session (either never clocked in today,
  /// or all their sessions have been clocked out).
  final List<Employee> notClockedIn;

  /// Open sessions — one per employee who is currently clocked in.
  final List<AttendanceRecord> clockedIn;

  /// Most recent clock-out time today for each employee in [notClockedIn]
  /// who has at least one completed session since the last board reset.
  /// Keyed by employee ID. Employees with no completed sessions (or whose
  /// sessions were all before the reset) have no entry here.
  final Map<String, DateTime> lastClockOutTimes;
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

/// The [DateTime] of the last successful board reset (email sent), or null.
/// Invalidate after a successful email send to trigger a board refresh.
final boardResetProvider = FutureProvider<DateTime?>((ref) {
  return BoardResetService.lastResetTime();
});

// ── Computed board state ──────────────────────────────────────────────────────

/// Combines [employeesProvider], [todayAttendanceProvider], and
/// [boardResetProvider] into a ready-to-render [AttendanceBoardState].
///
/// Returns [AsyncValue.loading] while any upstream provider is loading.
///
/// Sessions that started before today's board reset cutoff are treated as
/// archived and excluded from the active board (they remain in SQLite).
final attendanceBoardProvider =
    Provider<AsyncValue<AttendanceBoardState>>((ref) {
  final employeesAsync = ref.watch(employeesProvider);
  final attendanceAsync = ref.watch(todayAttendanceProvider);
  final resetAsync = ref.watch(boardResetProvider);

  if (employeesAsync.isLoading ||
      attendanceAsync.isLoading ||
      resetAsync.isLoading) {
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
  final allRecords = attendanceAsync.requireValue;
  final resetTime = resetAsync.requireValue; // DateTime? — null if never reset

  // Determine the cutoff: only apply the reset if it happened today.
  final now = DateTime.now();
  final todayMidnight = DateTime(now.year, now.month, now.day);
  final resetCutoff = (resetTime != null && resetTime.isAfter(todayMidnight))
      ? resetTime
      : null;

  // Active records are those that started after the reset cutoff (or all
  // records if no reset has happened today).
  final records = resetCutoff != null
      ? allRecords
          .where((r) => r.clockInTime.isAfter(resetCutoff))
          .toList()
      : allRecords;

  // Build a lookup: employeeId → open session (clockOutTime == null).
  final openSessions = <String, AttendanceRecord>{};
  for (final r in records) {
    if (r.clockOutTime == null) {
      openSessions[r.employeeId] = r;
    }
  }

  // Build a lookup: employeeId → most recent clock-out from closed sessions.
  final lastClockOut = <String, DateTime>{};
  for (final r in records) {
    if (r.clockOutTime != null) {
      final existing = lastClockOut[r.employeeId];
      if (existing == null || r.clockOutTime!.isAfter(existing)) {
        lastClockOut[r.employeeId] = r.clockOutTime!;
      }
    }
  }

  final notClockedIn = <Employee>[];
  final clockedIn = <AttendanceRecord>[];

  for (final emp in employees) {
    final openSession = openSessions[emp.id];
    if (openSession != null) {
      clockedIn.add(openSession);
    } else {
      notClockedIn.add(emp);
    }
  }

  return AsyncValue.data(AttendanceBoardState(
    notClockedIn: notClockedIn,
    clockedIn: clockedIn,
    lastClockOutTimes: lastClockOut,
  ));
});
