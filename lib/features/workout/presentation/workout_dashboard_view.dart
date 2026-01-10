import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/workout/data/workout_repository.dart';
import 'package:workout_tracker/features/workout/presentation/active_workout_page.dart';

class WorkoutView extends StatefulWidget {
  const WorkoutView({super.key});

  @override
  State<WorkoutView> createState() => _WorkoutViewState();
}

class _WorkoutViewState extends State<WorkoutView> {
  final WorkoutRepository _repo = WorkoutRepository();
  late String _todayName;

  @override
  void initState() {
    super.initState();
    _todayName = DateFormat('E').format(DateTime.now());
  }

  void _startFreestyle() async {
    // 1. Create Sesi di DB
    try {
      final workoutId = await _repo.startWorkout(templateName: 'Freestyle');

      if (mounted) {
        // 2. Navigasi ke Halaman Aktif
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActiveWorkoutPage(workoutId: workoutId),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // List Hari Singkat
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      appBar: AppBar(title: const Text('Training Center 🏋️')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.8),
                    Colors.black
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Ready to crush it?",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Consistency is the key to power.",
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _startFreestyle,
                    icon: const Icon(Icons.play_arrow, color: Colors.black),
                    label: const Text("START WORKOUT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text("Weekly Schedule",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Day Selector (Placeholder UI)
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final day = days[index];
                  final isToday = day == _todayName;
                  return Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppTheme.primaryColor
                          : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: isToday
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(day,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isToday ? Colors.black : Colors.grey)),
                        if (isToday)
                          const Icon(Icons.circle, size: 8, color: Colors.black)
                      ],
                    ),
                  );
                },
              ),
            ),

            const Spacer(),
            const Center(
              child: Text(
                "Select a day to view planned workout\n(Coming Soon in V2)",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
