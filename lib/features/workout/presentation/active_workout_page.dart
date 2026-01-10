import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/workout/data/workout_models.dart';
import 'package:workout_tracker/features/workout/data/workout_repository.dart';

class ActiveWorkoutPage extends StatefulWidget {
  final String workoutId; // ID Sesi dari DB

  const ActiveWorkoutPage({super.key, required this.workoutId});

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  final WorkoutRepository _repo = WorkoutRepository();

  // State
  Timer? _timer;
  int _secondsElapsed = 0;
  List<ActiveExerciseModel> _activeExercises = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  String get _formattedTimer {
    final m = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  // ➕ Add Exercise Logic
  void _showAddExerciseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => _ExercisePickerSheet(onSelect: (exercise) {
        setState(() {
          _activeExercises.add(ActiveExerciseModel(exercise: exercise));
        });
        Navigator.pop(context);
      }),
    );
  }

  // 💾 Finish Logic
  Future<void> _finishWorkout() async {
    setState(() => _isLoading = true);

    // Hitung Estimasi XP (Bisa dibuat lebih kompleks nanti)
    // Rumus simpel: 1 Set selesai = 10 XP
    int totalXP = 0;
    int totalSets = 0;

    for (var ex in _activeExercises) {
      for (var set in ex.sets) {
        if (set.isCompleted) {
          totalXP += 10;
          totalSets++;
        }
      }
    }
    // Bonus Finish
    totalXP += 50;
    int totalPoints = (totalXP / 5).floor(); // Rasio 1:5

    try {
      await _repo.finishWorkout(widget.workoutId, totalXP, totalPoints);

      if (mounted) {
        Navigator.pop(context); // Tutup halaman
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Workout Complete! +$totalXP XP 🔥"),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Active Session", style: TextStyle(fontSize: 16)),
            Text(_formattedTimer,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _finishWorkout,
            child: const Text("FINISH",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: _activeExercises.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fitness_center,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("No exercises yet.",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _showAddExerciseSheet,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor),
                    child: const Text("ADD EXERCISE",
                        style: TextStyle(color: Colors.black)),
                  )
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _activeExercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final activeEx = _activeExercises[index];
                return _ActiveExerciseCard(
                  activeEx: activeEx,
                  workoutId: widget.workoutId,
                  repo: _repo,
                  onUpdate: () => setState(() {}),
                );
              },
            ),
      floatingActionButton: _activeExercises.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddExerciseSheet,
              backgroundColor: AppTheme.primaryColor,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text("Add Exercise",
                  style: TextStyle(color: Colors.black)),
            ),
    );
  }
}

// --- SUB-WIDGETS (Supaya file gak kepanjangan) ---

class _ActiveExerciseCard extends StatelessWidget {
  final ActiveExerciseModel activeEx;
  final String workoutId;
  final WorkoutRepository repo;
  final VoidCallback onUpdate;

  const _ActiveExerciseCard({
    required this.activeEx,
    required this.workoutId,
    required this.repo,
    required this.onUpdate,
  });

  void _addSet() {
    activeEx.sets.add(WorkoutSetModel(
      setNumber: activeEx.sets.length + 1,
      tier: 'D', // Default
      targetValue: 10,
    ));
    onUpdate();
  }

  void _toggleSet(WorkoutSetModel set) async {
    // Optimistic Update
    set.isCompleted = !set.isCompleted;
    set.completedValue = set.isCompleted ? set.targetValue : null;
    onUpdate();

    // Save to DB
    try {
      await repo.saveSet(
        workoutId: workoutId,
        exerciseId: activeEx.exercise.id,
        set: set,
        workoutExerciseId: activeEx.id,
      );
    } catch (e) {
      debugPrint("Error saving set: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Judul
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(activeEx.exercise.name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  onPressed: () {}, // Nanti bisa buat hapus exercise
                )
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Header Kolom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: const [
                SizedBox(
                    width: 30,
                    child: Text("Set", style: TextStyle(color: Colors.grey))),
                Expanded(
                    child: Center(
                        child: Text("Previous",
                            style: TextStyle(color: Colors.grey)))),
                SizedBox(
                    width: 60,
                    child: Center(
                        child:
                            Text("Kg", style: TextStyle(color: Colors.grey)))),
                SizedBox(
                    width: 60,
                    child: Center(
                        child: Text("Reps",
                            style: TextStyle(color: Colors.grey)))),
                SizedBox(width: 40),
              ],
            ),
          ),

          // List Sets
          ...activeEx.sets.map((set) {
            return Container(
              color: set.isCompleted ? Colors.green.withOpacity(0.1) : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                      width: 30,
                      child: Text("${set.setNumber}",
                          style: const TextStyle(color: Colors.white))),
                  const Expanded(
                      child: Center(
                          child: Text("-",
                              style: TextStyle(
                                  color: Colors.grey)))), // History placeholder

                  // Input Weight
                  SizedBox(
                    width: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(4)),
                      child: Center(
                          child: Text("${set.weightKg}",
                              style: const TextStyle(color: Colors.white))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Input Reps
                  SizedBox(
                    width: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(4)),
                      child: Center(
                          child: Text("${set.targetValue}",
                              style: const TextStyle(color: Colors.white))),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Checkbox
                  InkWell(
                    onTap: () => _toggleSet(set),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: set.isCompleted ? Colors.green : Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.check,
                          size: 16, color: Colors.white),
                    ),
                  )
                ],
              ),
            );
          }).toList(),

          // Add Set Button
          InkWell(
            onTap: _addSet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              alignment: Alignment.center,
              child: const Text("+ Add Set",
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

// Widget Pilih Exercise
class _ExercisePickerSheet extends StatelessWidget {
  final Function(ExerciseModel) onSelect;

  const _ExercisePickerSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text("Select Exercise",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<ExerciseModel>>(
              future: WorkoutRepository().getExercises(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final exercises = snapshot.data!;
                return ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final ex = exercises[index];
                    return ListTile(
                      title: Text(ex.name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(ex.targetMuscle,
                          style: const TextStyle(color: Colors.grey)),
                      trailing: const Icon(Icons.add_circle_outline,
                          color: AppTheme.primaryColor),
                      onTap: () => onSelect(ex),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
