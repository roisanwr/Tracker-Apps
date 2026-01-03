import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Menggunakan absolute path agar lebih aman terbaca oleh IDE
import 'package:workout_tracker/core/theme/app_theme.dart';
// Import halaman login untuk navigasi saat logout
import 'package:workout_tracker/features/auth/presentation/login_page.dart';

import 'package:workout_tracker/features/tracker/dashboard_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final String _userId = Supabase.instance.client.auth.currentUser!.id;

  // 🕵️‍♂️ SPARKY NOTE: Kita siapin 4 halaman placeholder dulu ya.
  // Nanti masing-masing akan kita pisah jadi file sendiri biar rapi.
  static const List<Widget> _pages = <Widget>[
    _DashboardView(), // Halaman 0: HQ / Profile Summary
    _WorkoutView(),   // Halaman 1: Training Ground
    _TaskView(),      // Halaman 2: Daily Missions
    _ShopView(),      // Halaman 3: Rewards Market
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Fungsi Logout
  Future<void> _handleLogout() async {
    // 1. Sign out dari Supabase
    await Supabase.instance.client.auth.signOut();
    
    // 2. Cek apakah widget masih aktif sebelum navigasi (Best Practice)
    if (mounted) {
      // 3. Lempar balik ke Login Page & hapus semua history route sebelumnya
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Cyberpunk Background
      
      // ⚡ RPG STATUS BAR (Header Persisten)
      // Ini akan selalu muncul di halaman manapun
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: _buildRpgHeader(),
      ),
      
      body: Center(
        child: _pages.elementAt(_selectedIndex),
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_customize),
            label: 'HQ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Training',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Missions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.diamond_outlined),
            label: 'Market',
          ),
        ],
        currentIndex: _selectedIndex,
        // Menggunakan warna langsung dari AppTheme tanpa const untuk menghindari error linter
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1E1E1E),
        type: BottomNavigationBarType.fixed, // Biar 4 icon muat
        onTap: _onItemTapped,
      ),
    );
  }

  // 🧠 FITUR CANGGIH: REAL-TIME HEADER
  // Header ini nge-listen langsung ke database.
  // XP nambah? Angka langsung berubah!
  Widget _buildRpgHeader() {
    final stream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', _userId);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Loading state (skeleton sederhana)
          return AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const LinearProgressIndicator(),
          );
        }

        final data = snapshot.data!.first;
        final int level = data['level'] ?? 1;
        final int currentXp = data['current_xp'] ?? 0;
        final int points = data['current_points'] ?? 0;
        final int streak = data['streak_current'] ?? 0;
        final String username = data['username'] ?? 'Player';

        // Hitung Progress XP (Contoh sederhana: XP / (Level * 1000))
        // Nanti kita sesuaikan dengan rumus Level di database
        double xpProgress = (currentXp % 1000) / 1000; 

        return AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          toolbarHeight: 80,
          // Tombol Logout ditambahkan di sini (actions)
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                tooltip: 'Logout',
                onPressed: _handleLogout,
              ),
            ),
          ],
          title: Row(
            children: [
              // 1. AVATAR & LEVEL
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                   CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[800],
                    child: const Icon(Icons.person, color: Colors.white),
                    // Nanti ganti dengan Image.network(data['avatar_url'])
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    // Hapus 'const' di sini agar AppTheme.primaryColor terbaca aman
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$level',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              
              // 2. XP BAR & NAME
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      username.split('@')[0], // Ambil nama depan email
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 16
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: xpProgress,
                        backgroundColor: Colors.grey[800],
                        color: AppTheme.secondaryColor, // Warna XP
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'XP: $currentXp',
                      style: TextStyle(color: Colors.grey[400], fontSize: 10),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 3. CURRENCY & STREAK
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        '$points',
                        style: const TextStyle(
                          color: Color(0xFFFFD700), // Gold Color
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$streak Days',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 14),
                    ],
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// 🚧 PLACEHOLDER WIDGETS (SKELETON)
// Nanti kita pindahin ke file terpisah satu per satu
// =============================================================================

class _DashboardView extends StatelessWidget {
  const _DashboardView();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('📊 DASHBOARD HEATMAP HERE', style: TextStyle(color: Colors.white)));
  }
}

class _WorkoutView extends StatelessWidget {
  const _WorkoutView();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('⚔️ WORKOUT MENU HERE', style: TextStyle(color: Colors.white)));
  }
}

class _TaskView extends StatelessWidget {
  const _TaskView();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('📜 DAILY TASKS HERE', style: TextStyle(color: Colors.white)));
  }
}

class _ShopView extends StatelessWidget {
  const _ShopView();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('💎 REWARDS SHOP HERE', style: TextStyle(color: Colors.white)));
  }
}