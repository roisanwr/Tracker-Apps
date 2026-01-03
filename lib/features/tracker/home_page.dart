import 'package:flutter/material.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/presentation/login_page.dart';
import '../../../../core/theme/app_theme.dart';

// [UNTUK NANTI] Kalau file RPG sudah dibuat, hapus tanda // di bawah ini:
// import '../../gamification/presentation/daily_quest_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();

  // Logic Logout: Hapus sesi, balik ke Login, gak bisa back
  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Tombol Logout di Kanan Atas
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: AppTheme.neonPink),
            tooltip: 'Terminate Session',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 80, color: AppTheme.neonBlue),
            const SizedBox(height: 20),
            const Text(
              'System Online', 
              style: TextStyle(fontSize: 20, letterSpacing: 2, color: Colors.white),
            ),
            const SizedBox(height: 40),
            
            // --- AREA MENU FITUR ---
            
            // Tombol RPG (Di-komen dulu biar gak merah kalau filenya belum ada)
            /* ElevatedButton.icon(
              icon: const Icon(Icons.gamepad),
              label: const Text('Misi Harian (RPG)'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DailyQuestPage()),
                );
              },
            ),
            */
            
            // Pesan Sementara
            const Text(
              "(Fitur RPG coming soon...)",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}