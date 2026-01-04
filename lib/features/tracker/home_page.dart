import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ⚡ IMPORT TIMEZONE
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/auth/presentation/login_page.dart';
import 'package:workout_tracker/features/tracker/dashboard_view.dart';
import 'package:workout_tracker/features/tracker/task_view.dart';
import 'package:workout_tracker/features/tracker/workout_view.dart';
import 'package:workout_tracker/features/tracker/shop_view.dart'; // 👈 Import ini

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final String _userId = Supabase.instance.client.auth.currentUser!.id;

  static const List<Widget> _pages = <Widget>[
    DashboardView(),
    WorkoutView(),
    TaskView(),
    ShopView(),
  ];

  @override
  void initState() {
    super.initState();
    // ⚡ AUTO-REPORT: Lapor Timezone ke Database saat aplikasi dibuka
    _updateUserTimezone();
  }

  // Fungsi untuk update Timezone User di Database
  Future<void> _updateUserTimezone() async {
    try {
      // 1. Ambil Timezone dari HP (Contoh: "Asia/Jakarta")
      final String currentTimezone = await FlutterTimezone.getLocalTimezone();

      // 2. Kirim ke Database
      await Supabase.instance.client
          .from('profiles')
          .update({'timezone': currentTimezone}).eq('id', _userId);

      // debugPrint("✅ Timezone updated to: $currentTimezone");
    } catch (e) {
      debugPrint("⚠️ Failed to update timezone: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF1E1E1E),
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildRpgHeader() {
    final stream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id']).eq('id', _userId);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
        final String username =
            data['username'] ?? data['full_name'] ?? 'Player';

        double xpProgress = (currentXp % 1000) / 1000;

        return AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          toolbarHeight: 80,
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
              // Avatar & Level
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[800],
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
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

              // XP Bar & Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      username.contains('@')
                          ? username.split('@')[0]
                          : username,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: xpProgress,
                        backgroundColor: Colors.grey[800],
                        color: AppTheme.secondaryColor,
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

              // Currency & Streak
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        '$points',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.monetization_on,
                          color: Color(0xFFFFD700), size: 16),
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
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.local_fire_department,
                          color: Colors.orangeAccent, size: 14),
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
