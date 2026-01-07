import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://aeewnevtxjvflswxscmu.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFlZXduZXZ0eGp2Zmxzd3hzY211Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1ODI1NDgsImV4cCI6MjA4MzE1ODU0OH0.QewzhwmAdMZWf-qSssYlUAc-KRhOJ4MHIOKAJpsdGdI',
  );

  runApp(const StuddyBudyyApp());
}

class StuddyBudyyApp extends StatelessWidget {
  const StuddyBudyyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StuddyBudyy',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.black87,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
    );
  }
}