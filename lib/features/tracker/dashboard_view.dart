import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Hapus import intl biar gak error
import 'package:workout_tracker/core/theme/app_theme.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  // 🕵️‍♂️ SPARKY NOTE:
  // Kita ambil data user langsung dari stream biar realtime.
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
        // 1. CEK LOADING
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        
        // 2. CEK ERROR
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }

        // 3. CEK DATA KOSONG (PROFIL BELUM DIBUAT)
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text("Profile Not Found", style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  "User ID: ${Supabase.instance.client.auth.currentUser?.id}", 
                  style: const TextStyle(color: Colors.grey, fontSize: 10)
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                     // Trigger ulang atau navigasi ke create profile jika perlu
                     // Biasanya trigger SQL 'handle_new_user' harusnya otomatis buat ini.
                  }, 
                  child: const Text("Refresh")
                )
              ],
            )
          );
        }

        final profile = snapshot.data!.first;
        final int level = profile['level'] ?? 1;
        final int currentXp = profile['current_xp'] ?? 0;
        final int currentPoints = profile['current_points'] ?? 0;
        final int streakCurrent = profile['streak_current'] ?? 0;
        final int streakMax = profile['streak_max'] ?? 0;
        // Fallback name kalau username null
        final String username = profile['username'] ?? profile['full_name'] ?? 'User';

        // Hitung Title berdasarkan Level (Logika Sederhana)
        String userTitle = 'Novice Walker';
        if (level >= 5) userTitle = 'Apprentice Grinder';
        if (level >= 10) userTitle = 'Iron Breaker';
        if (level >= 20) userTitle = 'Cyber Athlete';
        if (level >= 50) userTitle = 'Shadow Legend';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER SECTION (Identity)
              _buildIdentityCard(username, userTitle, level, currentXp),

              const SizedBox(height: 24),

              // 2. STREAK & CURRENCY ROW
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.local_fire_department,
                      iconColor: Colors.orangeAccent,
                      label: 'Current Streak',
                      value: '$streakCurrent Days',
                      subValue: 'Best: $streakMax',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.monetization_on,
                      iconColor: const Color(0xFFFFD700),
                      label: 'Credit Points',
                      value: '$currentPoints CP',
                      subValue: 'Spend in Market',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 3. ACTIVITY HEATMAP (GitHub Style)
              const Text(
                'ACTIVITY LOG',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildCustomHeatmap(),

              const SizedBox(height: 24),

              // 4. ATTRIBUTES (RPG Stats Placeholder)
              const Text(
                'ATTRIBUTES',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildAttributesGrid(),
              
              const SizedBox(height: 80), // Spacer bawah biar gak ketutup navbar
            ],
          ),
        );
      },
    );
  }

  // WIDGET: Identity Card (Top Section)
  Widget _buildIdentityCard(String name, String title, int level, int xp) {
    // Rumus XP Cap sederhana
    double progress = (xp % 1000) / 1000;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.secondaryColor, width: 2),
              color: Colors.grey[800],
            ),
            child: const Icon(Icons.person, size: 40, color: Colors.white54),
          ),
          const SizedBox(width: 16),
          
          // Info Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name.split('@')[0], // Ambil nama depan aja
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // Level & XP Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('LVL $level', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('${xp % 1000} / 1000 XP', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 6),
                
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.black,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET: Stat Card (Streak & Points)
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subValue,
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
        ],
      ),
    );
  }

  // WIDGET: Custom Heatmap
  Widget _buildCustomHeatmap() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(28, (index) {
              bool isActive = (index % 3 == 0) || (index % 5 == 0); 
              return Container(
                width: 24, 
                height: 24,
                decoration: BoxDecoration(
                  color: isActive 
                      ? AppTheme.primaryColor.withOpacity(0.6) 
                      : Colors.grey[900],
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
              const SizedBox(width: 4),
              Container(width: 10, height: 10, color: Colors.grey[900]),
              const SizedBox(width: 4),
              Container(width: 10, height: 10, color: AppTheme.primaryColor.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text('More', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }

  // WIDGET: Attributes Grid
  Widget _buildAttributesGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _buildAttrTile('STR', 'Strength', 'Lv. 2', Colors.redAccent),
        _buildAttrTile('INT', 'Intellect', 'Lv. 5', Colors.blueAccent),
        _buildAttrTile('VIT', 'Vitality', 'Lv. 3', Colors.greenAccent),
        _buildAttrTile('DEX', 'Dexterity', 'Lv. 1', Colors.purpleAccent),
      ],
    );
  }

  Widget _buildAttrTile(String code, String name, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(code, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
              Text(val, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}