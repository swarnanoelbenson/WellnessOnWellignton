import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database_helper.dart';
import '../services/email_service.dart';

/// The singleton [EmailService] for the app.
///
/// The service holds the daily-schedule [Timer] for the lifetime of the
/// [ProviderScope].  [ref.onDispose] cancels the timer on teardown so the
/// service does not leak in tests.
final emailServiceProvider = Provider<EmailService>((ref) {
  final service = EmailService(db: DatabaseHelper.instance);
  ref.onDispose(service.dispose);
  return service;
});
