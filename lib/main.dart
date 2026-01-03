import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/presentation/login_page.dart'; // <-- Import yang benar (jalur baru)
import 'core/theme/app_theme.dart'; // Import file tadi

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- CONFIG SUPABASE KAMU ---
  // Pastikan URL dan KEY ini sesuai dengan yang kamu punya sebelumnya!
  await Supabase.initialize(
    url: 'https://krhymrkgjoyobynwvdrc.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtyaHltcmtnam95b2J5bnd2ZHJjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0MjE4MjMsImV4cCI6MjA4Mjk5NzgyM30.cKOWH12lW3t450TvcL25sU--pQPDhOH-W1Jox4zVXrA',
  );
  // ----------------------------

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Tracker',
      debugShowCheckedModeBanner: false, // Hilangkan pita debug
      theme: AppTheme.darkTheme, // <--- PAKAI INI
      home: const LoginPage(),
    );
  }
}