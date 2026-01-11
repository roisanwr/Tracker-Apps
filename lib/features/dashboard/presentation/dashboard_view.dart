import 'package:flutter/material.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  // Minimal HQ dashboard: show player summary and quick actions.
  int _level = 1;
  int _currentXp = 0;
  int _points = 0;

  @override
  void initState() {
    super.initState();
    // real app should load from Supabase; keep placeholder values for now
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HEADQUARTERS',
              style: TextStyle(
                  color: Colors.grey, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Level $_level',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('XP: $_currentXp',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Points', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('$_points',
                      style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),

          // Quick actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor),
                  onPressed: () {},
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('View Profile',
                        style: TextStyle(color: Colors.black)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24)),
                  onPressed: () {},
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Leaderboards',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text('Today\'s Briefing',
              style: TextStyle(
                  color: Colors.grey, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Text(
                  'Welcome back — choose Training to start your session',
                  style: TextStyle(color: Colors.grey[400])),
            ),
          ),
        ],
      ),
    );
  }
}
