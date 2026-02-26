import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database_helper.dart';
import '../data/firebase/firestore_service.dart';
import '../models/admin_user.dart';
import '../services/auth_service.dart';

/// The singleton [AuthService] wired up with the production database and
/// Firestore service.  All auth calls go through this provider.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    db: DatabaseHelper.instance,
    firestore: FirestoreService(),
  );
});

/// Holds the currently authenticated [AdminUser], or null when no admin
/// session is active.
///
/// Set to an [AdminUser] on successful [AuthService.loginAdmin].
/// Reset to null when the admin logs out or the 5-minute inactivity timer
/// fires (implemented in the admin panel widget in a later phase).
final adminSessionProvider = StateProvider<AdminUser?>((ref) => null);
