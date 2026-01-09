import 'package:flutter/material.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/dashboard/data/dashboard_repository.dart';
// ⚠️ Pastikan path ini sesuai dengan lokasi widget StatRadarChart kamu

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final DashboardRepository _repository = DashboardRepository();

  // Variable Data
  Map<String, dynamic>? _userStats;
  Map<String, double>? _attributes;

  // Variable Mockup untuk data tambahan (bisa dipindah ke Repo nanti)
  final List<int> _weeklyActivity = [3, 5, 2, 0, 4, 6, 4]; // Sen-Ming
  final List<Map<String, dynamic>> _todaysMissions = [
    {"title": "Upper Body Power", "xp": 150, "done": false},
    {"title": "Cardio Rush", "xp": 100, "done": true},
    {"title": "Drink 2L Water", "xp": 50, "done": false},
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _repository.fetchUserStats(),
        _repository.fetchPhysicalAttributes(),
      ]);

      if (mounted) {
        setState(() {
          _userStats = results[0] as Map<String, dynamic>;
          _attributes = results[1] as Map<String, double>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.neonBlue));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Section (Profile & XP)
          _buildHeader(),
          const SizedBox(height: 24),

          // 2. Stats Overview (Streak, Calories, Hours) - NEW!
          _buildStatsOverview(),
          const SizedBox(height: 24),

          // 3. Attribute Matrix (Radar Chart)
          // _buildRadarSection(),
          // const SizedBox(height: 24),

          // 4. Weekly Activity Graph - NEW!
          _buildWeeklyProgress(),
          const SizedBox(height: 24),

          // 5. Today's Missions - NEW!
          _buildTodaysMissions(),
          const SizedBox(height: 24),

          // 6. Quick Actions
          const Text(
            "QUICK ACTIONS",
            style: TextStyle(
              color: AppTheme.neonBlue,
              fontSize: 14,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActionCard(
              Icons.play_arrow, "Start Quick Workout", "Recommended for you"),
          _buildQuickActionCard(Icons.shopping_bag_outlined, "Visit Item Shop",
              "New items available"),
          const SizedBox(height: 80), // Space for BottomNavBar
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader() {
    final double progress =
        (_userStats?['current_xp'] ?? 0) / (_userStats?['max_xp'] ?? 1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24), // Lebih rounded
        border: Border.all(color: AppTheme.neonBlue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.neonBlue.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Avatar Circle
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.neonBlue),
                      image: _userStats?['avatar_url'] != null
                          ? DecorationImage(
                              image: NetworkImage(_userStats!['avatar_url']))
                          : null,
                    ),
                    child: _userStats?['avatar_url'] == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "WELCOME BACK,",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        (_userStats?['username'] ?? "Agent").toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.neonBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.neonBlue.withOpacity(0.5)),
                ),
                child: Text(
                  "LVL ${_userStats?['level'] ?? 1}",
                  style: const TextStyle(
                    color: AppTheme.neonBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${_userStats?['class'] ?? 'Rookie'} Class",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                "${_userStats?['current_xp']} / ${_userStats?['max_xp']} XP",
                style: const TextStyle(
                    color: AppTheme.neonBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              color: AppTheme.neonBlue,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Row(
      children: [
        Expanded(
            child: _buildStatCard("Streak", "5 Days",
                Icons.local_fire_department, Colors.orange)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard(
                "Burned", "12.5k", Icons.flash_on, Colors.redAccent)),
        const SizedBox(width: 12),
        Expanded(
            child:
                _buildStatCard("Hours", "24h", Icons.timer, Colors.blueAccent)),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Widget _buildRadarSection() {
  //   return Column(
  //     children: [
  //       const Text(
  //         "ATTRIBUTE MATRIX",
  //         style: TextStyle(
  //           color: AppTheme.neonBlue,
  //           letterSpacing: 2,
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),
  //       const SizedBox(height: 16),
  //       SizedBox(
  //         height: 250, // Sedikit lebih compact
  //         child: StatRadarChart(
  //           stats: _attributes ?? {},
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildWeeklyProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "WEEKLY ACTIVITY",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final days = ["M", "T", "W", "T", "F", "S", "S"];
              final value = _weeklyActivity[index];
              final isToday = index == 4; // Mockup today is Friday

              return Column(
                children: [
                  Container(
                    width: 12,
                    height: (value * 10).toDouble() + 10, // Min height
                    decoration: BoxDecoration(
                      color: isToday ? AppTheme.neonBlue : Colors.grey[800],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    days[index],
                    style: TextStyle(
                        color: isToday ? AppTheme.neonBlue : Colors.grey[600],
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysMissions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TODAY'S MISSION",
          style: TextStyle(
            color: AppTheme.neonBlue,
            fontSize: 14,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._todaysMissions
            .map((mission) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: mission['done']
                        ? Border.all(color: AppTheme.neonBlue.withOpacity(0.5))
                        : Border.all(color: Colors.transparent),
                  ),
                  child: ListTile(
                    leading: Icon(
                      mission['done']
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: mission['done'] ? AppTheme.neonBlue : Colors.grey,
                    ),
                    title: Text(
                      mission['title'],
                      style: TextStyle(
                        color:
                            mission['done'] ? Colors.white : Colors.grey[300],
                        decoration:
                            mission['done'] ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    trailing: Text(
                      "+${mission['xp']} XP",
                      style: const TextStyle(
                          color: AppTheme.neonBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ))
            .toList(),
      ],
    );
  }

  Widget _buildQuickActionCard(IconData icon, String label, String subLabel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.neonBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.neonBlue),
        ),
        title: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subLabel,
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () {
          // Action logic placeholder
        },
      ),
    );
  }
}
