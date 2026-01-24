import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/user_session.dart';
import '../services/deep_link_manager.dart'; // 👈 ADD THIS
import 'exam_selection_screen.dart';
import 'main_app_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _fadeController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;

  final _deepLinkManager = DeepLinkManager(); // 👈 USE SINGLETON

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeOut,
      ),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeOutCubic,
      ),
    );

    _mainController.forward();
    _checkLoginAndNavigate();
  }

  Future<void> _checkLoginAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 3500));

    if (!mounted) return;

    bool isLoggedIn = await UserSession.checkLogin();

    // Navigate to appropriate screen
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        isLoggedIn && UserSession.hasCompletedOnboarding
            ? const MainAppScreen(initialTabIndex: 0)
            : const ExamSelectionScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    // 👇 NOTE: Deep link navigation will be handled by MainAppScreen
    // when user completes onboarding or if already logged in
  }

  @override
  void dispose() {
    _mainController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main logo animation
          Center(
            child: FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Image.asset(
                  'assets/edormy_logo.png',
                  width: 320,
                  height: 320,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // 👇 Show indicator if deep link detected
          if (_deepLinkManager.hasPendingNavigation())
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _logoFade,
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFF8A1FFF),
                        strokeWidth: 2.5,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Opening shared content...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}