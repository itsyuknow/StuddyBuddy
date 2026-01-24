import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;
import 'widgets/mobile_wrapper.dart';
import 'screens/splash_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/share_service.dart';
import 'services/deep_link_manager.dart'; // 👈 ADD THIS

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
  final _deepLinkManager = DeepLinkManager(); // 👈 USE SINGLETON

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

    // 👇 CHECK FOR DEEP LINKS IMMEDIATELY
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDeepLink();
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
    super.didChangeMetrics();
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus != null && !currentFocus.hasFocus) {
      currentFocus.unfocus();
    }

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  // 👇 CHECK FOR DEEP LINKS AND STORE GLOBALLY
  Future<void> _checkDeepLink() async {
    try {
      final uri = Uri.parse(html.window.location.href);
      final pathSegments = uri.pathSegments;

      print('📱 Checking deep link: ${uri.path}');
      print('📱 Path segments: $pathSegments');

      if (pathSegments.isEmpty || pathSegments.length < 2) {
        print('📱 No deep link detected');
        return;
      }

      final type = pathSegments[0];
      final identifier = pathSegments[1];

      Map<String, dynamic>? navigationData;

      // Handle short links: /p/abc123, /c/xyz789, /u/def456
      if (type == 'p' || type == 'c' || type == 'u') {
        print('🔗 Short link detected: /$type/$identifier');

        final resolved = await ShareService.resolveLink(identifier);

        if (resolved != null) {
          navigationData = resolved;
          print('✅ Resolved to: ${resolved['content_type']} - ${resolved['content_id']}');
        } else {
          print('❌ Failed to resolve short link');
        }
      }
      // Handle direct links: /post/id, /challenge/id, /user/id
      else if (type == 'post' || type == 'challenge' || type == 'user') {
        navigationData = {
          'content_type': type,
          'content_id': identifier,
        };
        print('🔗 Direct link detected: /$type/$identifier');
      }

      // 👇 STORE IN GLOBAL MANAGER (survives across screens)
      if (navigationData != null) {
        _deepLinkManager.setPendingNavigation(navigationData);
      }
    } catch (e) {
      print('❌ Error checking deep link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileWrapper(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Edormy',
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();

          final mediaQuery = MediaQuery.of(context);

          final adjustedChild = MediaQuery(
            data: mediaQuery.copyWith(
              textScaleFactor: mediaQuery.textScaleFactor.clamp(0.8, 1.3),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: child,
            ),
          );

          return adjustedChild;
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
        home: const SplashScreen(), // 👈 No need to pass data anymore
      ),
    );
  }
}

/// Global navigator key for auth-based routing
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();