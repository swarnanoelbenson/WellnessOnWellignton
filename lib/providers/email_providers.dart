import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database_helper.dart';
import '../services/email_service.dart';
import 'attendance_providers.dart';

/// The singleton [EmailService] for the app.
///
/// The service holds the daily-schedule [Timer] for the lifetime of the
/// [ProviderScope].  [ref.onDispose] cancels the timer on teardown so the
/// service does not leak in tests.
///
/// [onReportSent] is called after every successful email send. It invalidates
/// [boardResetProvider] and [todayAttendanceProvider] so the board refreshes
/// immediately to reflect the post-reset state.
final emailServiceProvider = Provider<EmailService>((ref) {
  final service = EmailService(
    db: DatabaseHelper.instance,
    onReportSent: () {
      ref.invalidate(boardResetProvider);
      ref.invalidate(todayAttendanceProvider);
    },
  );
  ref.onDispose(service.dispose);
  return service;
});
