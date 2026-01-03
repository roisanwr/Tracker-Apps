import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'register_page.dart';

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
      debugShowCheckedModeBanner: false, // <--- TAMBAHKAN BARIS INI
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

  // Fungsi Logout
  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    
    if (context.mounted) {
      // Pindah balik ke halaman Login & hapus riwayat navigasi sebelumnya
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Tracker'),
        actions: [
          // Tombol Logout di Pojok Kanan Atas
          IconButton(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'Halo! Kamu berhasil masuk.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            // Tombol Logout Cadangan di Tengah
            ElevatedButton.icon(
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Warna merah biar kelihatan tombol 'bahaya'
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}