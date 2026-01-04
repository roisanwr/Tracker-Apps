import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;

  // State untuk Data XP Mingguan
  List<Map<String, dynamic>> _weeklyXpData = [];
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchWeeklyXpStats();
  }

  // 📊 HITUNG XP HARIAN (7 HARI TERAKHIR)
  Future<void> _fetchWeeklyXpStats() async {
    try {
      final now = DateTime.now();
      // Ambil data 7 hari ke belakang (termasuk hari ini)
      final startDate = now.subtract(const Duration(days: 6));

      final response = await Supabase.instance.client
          .from('point_logs')
          .select('created_at, xp_change')
          .eq('user_id', _userId)
          .gte('created_at',
              DateFormat('yyyy-MM-dd').format(startDate)) // Filter tanggal
          .gt('xp_change',
              0) // Hanya ambil XP positif (gain), hukuman ga usah dihitung di grafik produktivitas
          .order('created_at', ascending: true);

      // Siapkan kerangka data 7 hari (biar kalau 0 tetap muncul)
      Map<String, int> xpPerDay = {};
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: 6 - i));
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        xpPerDay[dateKey] = 0;
      }

      // Isi data dari database
      for (var log in response) {
        final dateStr = DateTime.parse(log['created_at'])
            .toLocal()
            .toString()
            .split(' ')[0]; // Ambil YYYY-MM-DD
        if (xpPerDay.containsKey(dateStr)) {
          xpPerDay[dateStr] =
              (xpPerDay[dateStr] ?? 0) + (log['xp_change'] as int);
        }
      }

      // Konversi ke List untuk UI
      List<Map<String, dynamic>> chartData = [];
      xpPerDay.forEach((key, value) {
        final date = DateTime.parse(key);
        chartData.add({
          'day': DateFormat('E').format(date), // Mon, Tue
          'xp': value,
          'is_today': DateFormat('yyyy-MM-dd').format(now) == key,
        });
      });

      if (mounted) {
        setState(() {
          _weeklyXpData = chartData;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  // ✏️ EDIT USERNAME DIALOG
  void _showEditProfileDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text("Edit Codename", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLength: 12,
          decoration: const InputDecoration(
            hintText: "Enter new name",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey)),
            counterStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              // Update ke Database
              await Supabase.instance.client.from('profiles').update(
                  {'username': controller.text.trim()}).eq('id', _userId);

              // Refresh halaman biar nama berubah
              setState(() {});
            },
            child: const Text("Save", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
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
          onRefresh: _fetchWeeklyXpStats,
          color: AppTheme.primaryColor,
          backgroundColor: const Color(0xFF1E1E1E),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. CHARACTER STATUS (With Edit Button)
                _buildIdentitySection(profile, level, currentXp),

                const SizedBox(height: 30),

                // 2. XP HISTORY CHART (Pengganti Radar Chart) 📊
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8.0, bottom: 12.0),
                    child: Text(
                      "WEEKLY PERFORMANCE (XP)",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                _isLoadingStats
                    ? const SizedBox(
                        height: 180,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primaryColor)))
                    : _buildXpHistoryChart(),

                const SizedBox(height: 30),

                // 3. STATS ROW
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

                const SizedBox(height: 24),

                // 4. Activity Log (Simple Heatmap / Placeholder)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CONSISTENCY LOG',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                _buildCustomHeatmap(),

                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  // WIDGET: Simple Bar Chart Manual
  Widget _buildXpHistoryChart() {
    // Cari nilai max untuk skala grafik
    int maxXp = 100; // Default min scale
    for (var data in _weeklyXpData) {
      if (data['xp'] > maxXp) maxXp = data['xp'];
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end, // Bar tumbuh dari bawah
        children: _weeklyXpData.map((data) {
          final int xp = data['xp'];
          final String day = data['day'];
          final bool isToday = data['is_today'];

          // Hitung tinggi relatif (0.0 - 1.0)
          double barHeightFactor = xp / maxXp;
          if (barHeightFactor < 0.05 && xp > 0)
            barHeightFactor = 0.05; // Min height biar kelihatan dikit

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Label XP (muncul kalau ada XP)
              if (xp > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    "$xp",
                    style: TextStyle(
                        color: isToday ? AppTheme.primaryColor : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),

              // Batang Grafik
              Container(
                width: 12,
                height: 100 * barHeightFactor, // Max height 100 pixel
                decoration: BoxDecoration(
                  color: isToday ? AppTheme.primaryColor : Colors.grey[700],
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isToday
                      ? [
                          BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 1)
                        ]
                      : [],
                ),
              ),

              const SizedBox(height: 8),

              // Label Hari
              Text(
                day,
                style: TextStyle(
                  color: isToday ? Colors.white : Colors.grey,
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIdentitySection(
      Map<String, dynamic> profile, int level, int xp) {
    // Ambil nama (prioritas: username -> full_name -> Player)
    String username = profile['username'] ?? profile['full_name'] ?? 'Player';
    // Kalau ada email di username, ambil depannya aja (opsional, tergantung preferensi)
    // username = username.contains('@') ? username.split('@')[0] : username;

    String rank = "Novice";
    if (level > 10) rank = "Apprentice";
    if (level > 30) rank = "Adept";
    if (level > 50) rank = "Master";

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

        // NAMA & EDIT BUTTON
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              username.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5),
            ),
            const SizedBox(width: 8),
            // Tombol Edit Kecil
            InkWell(
              onTap: () => _showEditProfileDialog(username),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(Icons.edit, size: 16, color: Colors.grey[600]),
              ),
            )
          ],
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

  Widget _buildCustomHeatmap() {
    return Container(
      height: 120, // Kasih tinggi fix biar rapi
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F), // Lebih gelap dari card
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(35, (index) {
            bool active = (index * 7) % 3 ==
                0; // Masih visual random, nanti bisa di-connect
            return Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primaryColor.withOpacity((index % 5 + 1) * 0.2)
                    : Colors.grey[900],
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
    );
  }
}
