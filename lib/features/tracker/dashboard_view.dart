import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
// Import Widget Radar Chart (Pastikan file ini ada)
import 'package:workout_tracker/features/tracker/widgets/stat_radar_chart.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  Stream<List<Map<String, dynamic>>> _getProfileStream() {
    return Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', Supabase.instance.client.auth.currentUser!.id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getProfileStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              "Profile Not Found",
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final profile = snapshot.data!.first;
        final int level = profile['level'] ?? 1;
        final int currentXp = profile['current_xp'] ?? 0;
        final int currentPoints = profile['current_points'] ?? 0;
        final int streakCurrent = profile['streak_current'] ?? 0;

        // 🚧 DUMMY STATS (Persentase 0.0 - 1.0)
        final Map<String, double> rpgStats = {
          'STR': 0.7,
          'INT': 0.8,
          'VIT': 0.5,
          'DEX': 0.4,
          'CHA': 0.6,
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. CHARACTER STATUS
              _buildIdentitySection(profile, level, currentXp),

              const SizedBox(height: 30),

              // 2. RADAR CHART
              const Text(
                "ATTRIBUTE HEXAGON",
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 220,
                child: StatRadarChart(
                  data: rpgStats,
                  activeColor: AppTheme.primaryColor,
                ),
              ),

              const SizedBox(height: 30),

              // 3. ⚡ VISUAL ATTRIBUTES (GAMBAR ASSET DI SINI)
              // Bagian ini menampilkan ikon otot/otak yang kamu minta
              SizedBox(
                height: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageAssetCard(
                      'STR',
                      'Lv. 5',
                      'assets/images/icon_str.png',
                      Colors.greenAccent,
                    ),
                    _buildImageAssetCard(
                      'INT',
                      'Lv. 8',
                      'assets/images/icon_int.png',
                      Colors.blueAccent,
                    ),
                    _buildImageAssetCard(
                      'VIT',
                      'Lv. 3',
                      'assets/images/icon_vit.png',
                      Colors.redAccent,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 4. STATS ROW
              Row(
                children: [
                  Expanded(
                    child: _buildCompactStat(
                      "STREAK",
                      "$streakCurrent",
                      "Days",
                      Icons.local_fire_department,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCompactStat(
                      "CREDITS",
                      "$currentPoints",
                      "CP",
                      Icons.monetization_on,
                      Colors.amber,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  // WIDGET BARU: Kartu Atribut dengan Gambar
  Widget _buildImageAssetCard(
    String label,
    String value,
    String assetPath,
    Color glowColor,
  ) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glowColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Gambar Aset (Fallback ke Icon kalau gambar belum ada)
          SizedBox(
            height: 40,
            width: 40,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Tampilkan icon default kalau file gambar belum dimasukkan
                return Icon(
                  Icons.broken_image,
                  color: glowColor.withOpacity(0.5),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: glowColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentitySection(
    Map<String, dynamic> profile,
    int level,
    int xp,
  ) {
    String username = profile['username'] ?? profile['full_name'] ?? 'Player';
    username = username.split('@')[0];

    String rank = "Novice";
    if (level > 10) rank = "Apprentice";
    if (level > 30) rank = "Adept";
    if (level > 50) rank = "Master";

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
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
            letterSpacing: 1.5,
          ),
        ),
        Text(
          "$rank Lvl. $level",
          style: TextStyle(
            color: AppTheme.primaryColor.withOpacity(0.8),
            fontSize: 14,
          ),
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
            widthFactor: (xp % 1000) / 1000,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${xp % 1000} / 1000 XP",
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildCompactStat(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
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
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
