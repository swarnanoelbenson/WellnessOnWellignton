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

  // Seed dummy employees on first launch (no-op when DB already has data).
  await _seedDummyEmployees();

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
