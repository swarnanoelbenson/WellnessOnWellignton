import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database_helper.dart';
import '../data/firebase/firestore_service.dart';
import '../models/models.dart';
import '../services/admin_service.dart';

/// The singleton [AdminService] for the admin panel.
///
/// Uses the same Firebase-unavailable guard as [authServiceProvider] so the
/// panel works in SQLite-only mode before Firebase is configured.
final adminServiceProvider = Provider<AdminService>((ref) {
  FirestoreService? firestore;
  try {
    firestore = FirestoreService();
  } catch (_) {
    debugPrint('[Admin] FirestoreService unavailable — SQLite only.');
  }
  return AdminService(db: DatabaseHelper.instance, firestore: firestore);
});

/// All employees — invalidate after add / remove / reset-password.
final adminEmployeesProvider = FutureProvider<List<Employee>>((ref) {
  return DatabaseHelper.instance.getAllEmployees();
});

/// All public holidays sorted by date — invalidate after add / remove.
final adminHolidaysProvider = FutureProvider<List<PublicHoliday>>((ref) {
  return DatabaseHelper.instance.getAllPublicHolidays();
});

/// Parameterised attendance query used by the log view and reports section.
///
/// Records run from [from] to [to] (inclusive), newest first.
typedef AttendanceDateRange = ({DateTime from, DateTime to});

final attendanceForRangeProvider =
    FutureProvider.family<List<AttendanceRecord>, AttendanceDateRange>(
  (ref, range) => DatabaseHelper.instance
      .getAttendanceForDateRange(range.from, range.to),
);
