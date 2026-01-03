// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/tracker/home_page.dart'; // Pastikan import HomePage ada
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xybczhxtbaegdmmasvcr.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5YmN6aHh0YmFlZ2RtbWFzdmNyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0NDkyNjIsImV4cCI6MjA4MzAyNTI2Mn0.5FZ1_heSaRIw1lFajoGLSyvhZdPLzildknzfr2ZrR6A', // (Isi key kamu yg panjang itu)
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. CEK SESI SAAT INI 🕵️‍♂️
    // Supabase menyimpan sesi di penyimpanan lokal HP otomatis.
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;

    return MaterialApp(
      title: 'Workout Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      
      // 2. LOGIKA PENENTU HALAMAN AWAL 🚦
      // Kalau isLoggedIn true -> Ke HomePage
      // Kalau false -> Ke LoginPage
      home: isLoggedIn ? const HomePage() : const LoginPage(),
    );
  }
}