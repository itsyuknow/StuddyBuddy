import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/mobile_wrapper.dart';
import 'screens/splash_screen.dart';
import 'screens/reset_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Supabase.initialize(
    url: 'https://aeewnevtxjvflswxscmu.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFlZXduZXZ0eGp2Zmxzd3hzY211Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1ODI1NDgsImV4cCI6MjA4MzE1ODU0OH0.QewzhwmAdMZWf-qSssYlUAc-KRhOJ4MHIOKAJpsdGdI',
  );

  runApp(const StuddyBudyyApp());
}

class StuddyBudyyApp extends StatefulWidget {
  const StuddyBudyyApp({super.key});

  @override
  State<StuddyBudyyApp> createState() => _StuddyBudyyAppState();
}

class _StuddyBudyyAppState extends State<StuddyBudyyApp> with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
              (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Handle keyboard appearance/disappearance
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    debugPrint('Keyboard inset: $bottomInset');
  }

  @override
  Widget build(BuildContext context) {
    return MobileWrapper(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Edormy',
        // GLOBAL KEYBOARD HANDLING - Works on all screens
        builder: (context, child) {
          return PopScope(
            canPop: false,
            onPopInvoked: (bool didPop) async {
              if (didPop) return;

              // Check if keyboard is open
              final hasFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;

              if (hasFocus) {
                // Close keyboard and prevent navigation
                FocusManager.instance.primaryFocus?.unfocus();

                // Force scroll reset after keyboard closes
                await Future.delayed(const Duration(milliseconds: 100));
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // This ensures the view resets after keyboard animation
                });
              } else {
                // Allow navigation if keyboard is closed
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // Dismiss keyboard when tapping outside input fields
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: child!,
            ),
          );
        },
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF8A1FFF),
            secondary: Color(0xFFC43AFF),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF8A1FFF),
            foregroundColor: Colors.white,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8A1FFF),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8A1FFF),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF8A1FFF),
            foregroundColor: Colors.white,
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: Color(0xFF8A1FFF),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8A1FFF), width: 2),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

/// Global navigator key for auth-based routing
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();