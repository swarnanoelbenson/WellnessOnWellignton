import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database/database_helper.dart';
import 'models/models.dart';
import 'screens/splash_screen.dart';
import 'utils/password_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to landscape — the app is tablet-only.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Firebase initialisation.
  // Requires google-services.json (Android) and GoogleService-Info.plist (iOS).
  // Run `flutterfire configure` to generate lib/firebase_options.dart, then
  // replace the try/catch with:
  //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[Firebase] Not initialised — offline mode active. Error: $e');
  }

  // Seed dummy employees and admin accounts on first launch.
  await _seedDummyEmployees();
  await _seedAdminUsers();

  runApp(
    const ProviderScope(
      child: WellnessOnWellingtonApp(),
    ),
  );
}

/// Seeds 8 dummy employees with the default password on first launch.
///
/// Safe to call on every start — exits immediately if employees already exist.
/// The default password hash is computed once and reused for all employees.
Future<void> _seedDummyEmployees() async {
  final db = DatabaseHelper.instance;
  if ((await db.getAllEmployees()).isNotEmpty) return;

  // Compute the default-password hash once (bcrypt is intentionally slow).
  final hash = PasswordUtils.hashPassword(PasswordUtils.defaultPassword);

  const names = [
    'Alice Johnson',
    'Bob Smith',
    'Carol Williams',
    'David Brown',
    'Eve Davis',
    'Frank Miller',
    'Grace Lee',
    'Henry Wilson',
  ];

  for (final name in names) {
    await db.insertEmployee(Employee.create(name: name, defaultPasswordHash: hash));
  }

  debugPrint('[Seed] Inserted ${names.length} dummy employees.');
}

/// Seeds 2 admin accounts on first launch (no-op when accounts already exist).
///
/// Credentials are printed to the debug console on every launch so they are
/// easy to find during development.  Change these before going to production
/// by deleting the app data (or the SQLite DB file) and restarting with the
/// desired credentials hardcoded below.
Future<void> _seedAdminUsers() async {
  final db = DatabaseHelper.instance;

  // Always log current admin state so the developer can verify.
  final existing = await db.getAllAdmins();
  if (existing.isNotEmpty) {
    debugPrint('[Admin] ${existing.length} admin account(s) already in DB:');
    for (final a in existing) {
      debugPrint('[Admin]   username: "${a.username}"');
    }
    return;
  }

  // Seed the two default admin accounts.
  const accounts = [
    (username: 'admin',   password: 'admin123'),
    (username: 'manager', password: 'manager123'),
  ];

  for (final a in accounts) {
    final hash = PasswordUtils.hashPassword(a.password);
    await db.insertAdminUser(
      AdminUser.create(username: a.username, passwordHash: hash),
    );
  }

  debugPrint('[Seed] Inserted ${accounts.length} admin accounts.');
  debugPrint('[Seed] ─────────────────────────────────────────');
  debugPrint('[Seed]   username : "admin"     password : "admin123"');
  debugPrint('[Seed]   username : "manager"   password : "manager123"');
  debugPrint('[Seed] ─────────────────────────────────────────');
}

class WellnessOnWellingtonApp extends StatelessWidget {
  const WellnessOnWellingtonApp({super.key});

  // Brand colours — referenced by sub-widgets via WellnessOnWellingtonApp.crimson
  static const Color crimson = Color(0xFF8B0000);
  static const Color charcoal = Color(0xFF2C2C2C);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wellness on Wellington',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: crimson,
          primary: crimson,
          onPrimary: Colors.white,
          secondary: charcoal,
          onSecondary: Colors.white,
          surface: const Color(0xFFFAFAFA),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
