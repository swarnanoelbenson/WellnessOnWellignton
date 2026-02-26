import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/database_helper.dart';
import '../data/firebase/firestore_service.dart';
import '../models/admin_user.dart';
import '../services/auth_service.dart';

/// The singleton [AuthService] wired up with the production database and,
/// when Firebase is configured, the Firestore sync layer.
///
/// [FirestoreService] accesses [FirebaseFirestore.instance] eagerly in its
/// constructor, which throws if Firebase has not been initialised (e.g. before
/// `flutterfire configure` has been run).  The try-catch here ensures the app
/// runs in SQLite-only mode rather than crashing the provider.
final authServiceProvider = Provider<AuthService>((ref) {
  FirestoreService? firestoreService;
  try {
    firestoreService = FirestoreService();
  } catch (_) {
    // Firebase not yet configured — Firestore sync will be skipped.
    debugPrint('[Auth] FirestoreService unavailable — running SQLite-only.');
  }
  return AuthService(
    db: DatabaseHelper.instance,
    firestore: firestoreService,
  );
});

/// Holds the currently authenticated [AdminUser], or null when no admin
/// session is active.
///
/// Set to an [AdminUser] on successful [AuthService.loginAdmin].
/// Reset to null when the admin logs out or the 5-minute inactivity timer
/// fires (implemented in the admin panel widget in a later phase).
final adminSessionProvider = StateProvider<AdminUser?>((ref) => null);
