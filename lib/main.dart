import 'package:flutter/material.dart';
import 'package:workout_tracker/core/services/supabase_service.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
// Nanti kita arahkan ke SplashPage atau AuthGate, sementara ke Container kosong dulu gpp
// import 'features/auth/presentation/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/features/auth/presentation/login_page.dart';
import 'package:workout_tracker/features/dashboard/presentation/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi Database lewat Service baru kita
  await SupabaseService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Tracker RPG',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Ambil dari core/theme

      // LOGIKA NAVIGASI SEMENTARA:
      // Kita cek langsung status auth dari Service
      home: SupabaseService().isAuthenticated
          ? const HomePage()
          : const LoginPage(), // <-- Gunakan Login Page yang baru
    );
  }
}

// --- WIDGET SEMENTARA (Biar gak error pas di-run sebelum kita pindahin fitur lain) ---
class TempHomePage extends StatelessWidget {
  const TempHomePage({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text("Home (Refactoring...)")));
}

class TempLoginPage extends StatelessWidget {
  const TempLoginPage({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text("Login (Refactoring...)")));
}
