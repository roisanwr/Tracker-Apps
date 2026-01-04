import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/tracker/widgets/stat_radar_chart.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;

  // State untuk menyimpan statistik RPG
  Map<String, double> _rpgStats = {
    'STR': 0.1,
    'INT': 0.1,
    'VIT': 0.1,
    'DEX': 0.1,
    'CHA': 0.1,
  };

  // State level visual (untuk teks Lv. 1, Lv. 5, dll)
  Map<String, int> _rpgLevels = {
    'STR': 1,
    'INT': 1,
    'VIT': 1,
    'DEX': 1,
    'CHA': 1
  };

  @override
  void initState() {
    super.initState();
    _calculateRealStats(); // Hitung statistik saat halaman dibuka
  }

  // 🧠 RPG ENGINE: Hitung statistik berdasarkan riwayat aktivitas
  Future<void> _calculateRealStats() async {
    try {
      // 1. Ambil Hitungan Task yang Selesai per Kategori
      final tasksResponse = await Supabase.instance.client
          .from('tasks')
          .select('category')
          .eq('user_id', _userId)
          .eq('is_completed', true);

      // 2. Ambil Hitungan Workout yang Selesai
      final workoutsResponse = await Supabase.instance.client
          .from('workouts')
          .select('id') // Cukup ID aja
          .eq('user_id', _userId)
          .eq('status', 'completed');

      // 3. Hitung Total Poin Mentah
      int strRaw = workoutsResponse.length; // 1 Workout = 1 Poin STR
      int intRaw = 0;
      int vitRaw = 0;
      int chaRaw = 0;
      int dexRaw = 0;

      for (var t in tasksResponse) {
        final cat = t['category'];
        if (cat == 'Intellect')
          intRaw++;
        else if (cat == 'Vitality')
          vitRaw++;
        else if (cat == 'Charisma')
          chaRaw++;
        else if (cat == 'Wealth') dexRaw++; // Wealth masuk ke DEX
      }

      // 4. Normalisasi Data (0.0 - 1.0) untuk Radar Chart
      // Anggap Level 10 (Max Stats) butuh 50 poin aktivitas.
      double normalize(int val) {
        double res = val / 50.0;
        return res > 1.0
            ? 1.0
            : (res < 0.1 ? 0.1 : res); // Min 0.1 biar grafik gak hilang
      }

      // Hitung Level Visual (Simple: Poin / 5)
      int calcLevel(int val) => (val ~/ 5) + 1;

      if (mounted) {
        setState(() {
          _rpgStats = {
            'STR': normalize(strRaw),
            'INT': normalize(intRaw),
            'VIT': normalize(vitRaw),
            'DEX': normalize(dexRaw),
            'CHA': normalize(chaRaw),
          };

          _rpgLevels = {
            'STR': calcLevel(strRaw),
            'INT': calcLevel(intRaw),
            'VIT': calcLevel(vitRaw),
            'DEX': calcLevel(dexRaw),
            'CHA': calcLevel(chaRaw),
          };
        });
      }
    } catch (e) {
      debugPrint("Error calculating stats: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> _getProfileStream() {
    return Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id']).eq('id', _userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getProfileStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
              child: Text("Profile Not Found",
                  style: TextStyle(color: Colors.white)));
        }

        final profile = snapshot.data!.first;
        final int level = profile['level'] ?? 1;
        final int currentXp = profile['current_xp'] ?? 0;
        final int currentPoints = profile['current_points'] ?? 0;
        final int streakCurrent = profile['streak_current'] ?? 0;

        return RefreshIndicator(
          onRefresh: _calculateRealStats, // Tarik layar untuk refresh statistik
          color: AppTheme.primaryColor,
          backgroundColor: const Color(0xFF1E1E1E),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. CHARACTER STATUS
                _buildIdentitySection(profile, level, currentXp),

                const SizedBox(height: 30),

                // 2. RADAR CHART (REAL DATA) 🕸️
                const Text(
                  "ATTRIBUTE HEXAGON",
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 220,
                  child: StatRadarChart(
                    data: _rpgStats,
                    activeColor: AppTheme.primaryColor,
                  ),
                ),

                const SizedBox(height: 30),

                // 3. VISUAL ATTRIBUTES (Dengan Icon, bukan Image Asset biar aman)
                // Menampilkan Level Stat yang sudah dihitung
                SizedBox(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttributeCard('STR', 'Lv. ${_rpgLevels['STR']}',
                          Icons.fitness_center, Colors.redAccent),
                      _buildAttributeCard('INT', 'Lv. ${_rpgLevels['INT']}',
                          Icons.psychology, Colors.blueAccent),
                      _buildAttributeCard('VIT', 'Lv. ${_rpgLevels['VIT']}',
                          Icons.favorite, Colors.greenAccent),
                      _buildAttributeCard('DEX', 'Lv. ${_rpgLevels['DEX']}',
                          Icons.flash_on, Colors.purpleAccent),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 4. STATS ROW
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactStat("STREAK", "$streakCurrent",
                          "Days", Icons.local_fire_department, Colors.orange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactStat("CREDITS", "$currentPoints",
                          "CP", Icons.monetization_on, Colors.amber),
                    ),
                  ],
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  // WIDGET: Kartu Atribut dengan Icon
  Widget _buildAttributeCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      width: 70,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 0,
            )
          ]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildIdentitySection(
      Map<String, dynamic> profile, int level, int xp) {
    String username = profile['username'] ?? profile['full_name'] ?? 'Player';
    username = username.split('@')[0];

    String rank = "Novice";
    if (level > 10) rank = "Apprentice";
    if (level > 30) rank = "Adept";
    if (level > 50) rank = "Master";

    // Hitung progress bar level (0.0 - 1.0)
    // Asumsi per level butuh 1000 XP (atau bisa ambil dari level rules nanti)
    double progress = (xp % 1000) / 1000;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ]),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF1E1E1E),
            child: const Icon(Icons.person, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          username.toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5),
        ),
        Text(
          "$rank Lvl. $level",
          style: TextStyle(
              color: AppTheme.primaryColor.withOpacity(0.8), fontSize: 14),
        ),
        const SizedBox(height: 16),
        Container(
          height: 6,
          width: 150,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text("${xp % 1000} / 1000 XP",
            style: TextStyle(color: Colors.grey[600], fontSize: 10)),
      ],
    );
  }

  Widget _buildCompactStat(
      String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 10, letterSpacing: 1)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text(unit,
                      style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}
