import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'main_screen.dart';

/// Full-screen branded splash shown for 2.5 s on first launch.
///
/// Content fades in immediately, then the screen cross-fades to [MainScreen].
/// No interactive elements — display only.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _crimson = Color(0xFF8B0000);

  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Fade the content in over 400 ms.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // Navigate to the main board after 2.5 s.
    _navTimer = Timer(
      const Duration(milliseconds: 2500),
      _navigateToMain,
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const MainScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _crimson,
      body: FadeTransition(
        opacity: _fadeIn,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Clinic logo
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 220,
                  maxHeight: 220,
                ),
                child: Image.asset(
                  'wellness_on_wellington_logo.jpg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 36),

              // Subtitle
              Text(
                'Attendance Tracker',
                style: GoogleFonts.nunito(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
