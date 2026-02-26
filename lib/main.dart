import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

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
  // replace the try/catch below with:
  //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Firebase config files not yet present — the app runs in offline/SQLite
    // mode. Firestore sync will be unavailable until Firebase is configured.
    debugPrint('[Firebase] Not initialised — offline mode active. Error: $e');
  }

  runApp(
    const ProviderScope(
      child: WellnessOnWellingtonApp(),
    ),
  );
}

class WellnessOnWellingtonApp extends StatelessWidget {
  const WellnessOnWellingtonApp({super.key});

  // Brand colours
  static const Color crimson = Color(0xFF8B0000);   // deep red
  static const Color charcoal = Color(0xFF2C2C2C);  // dark charcoal grey

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
      // Phase 1 placeholder — replaced in Phase 2 with the real home screen.
      home: const _Phase1Placeholder(),
    );
  }
}

/// Temporary scaffold shown during Phase 1.
/// Confirms that the app boots, Firebase initialises, and Riverpod is active.
class _Phase1Placeholder extends StatelessWidget {
  const _Phase1Placeholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WellnessOnWellingtonApp.crimson,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, color: Colors.white, size: 64),
            const SizedBox(height: 24),
            Text(
              'Wellness on Wellington',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Phase 1 — Data Models ✓',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
