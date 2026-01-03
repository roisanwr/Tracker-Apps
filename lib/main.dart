import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- BAGIAN INI WAJIB DIGANTI ---
  // Ambil dari Dashboard Supabase > Project Settings > API
  await Supabase.initialize(
    url: 'https://krhymrkgjoyobynwvdrc.supabase.co', // Ganti dengan Project URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtyaHltcmtnam95b2J5bnd2ZHJjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc0MjE4MjMsImV4cCI6MjA4Mjk5NzgyM30.cKOWH12lW3t450TvcL25sU--pQPDhOH-W1Jox4zVXrA', // Ganti dengan Anon / Public Key
  );
  // --------------------------------

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Tracker')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Koneksi Supabase Berhasil!'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Nanti kita tambah fungsi tes database di sini
                print("Tombol ditekan"); 
              },
              child: const Text('Tes Koneksi'),
            ),
          ],
        ),
      ),
    );
  }
}