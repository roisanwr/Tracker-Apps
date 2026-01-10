import 'dart:async';
import 'package:flutter/material.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/workout/data/workout_models.dart';
import 'package:workout_tracker/features/workout/data/workout_repository.dart';

class ActiveWorkoutPage extends StatefulWidget {
  final List<ExerciseModel> initialExercises; // 🔥 Terima Data dari Planner
  final String sessionName;

  const ActiveWorkoutPage(
      {super.key,
      this.initialExercises = const [],
      this.sessionName = "Workout"});

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  final WorkoutRepository _repo = WorkoutRepository();

  // State UI & Data
  String? _workoutId; // ID Database untuk sesi ini
  List<ActiveExerciseModel> _activeExercises = [];
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // 1. Setup Awal: Mapping data template ke model aktif (memory)
    if (widget.initialExercises.isNotEmpty) {
      _activeExercises = widget.initialExercises
          .map((ex) => ActiveExerciseModel(exercise: ex, sets: []))
          .toList();
    } else {
      // Kalau kosong (freestyle), biarkan list kosong nanti user tambah sendiri
    }

    // 2. AUTO START: Bikin sesi di Database
    _initSession();
  }

  Future<void> _initSession() async {
    try {
      final id = await _repo.startActiveWorkout(widget.sessionName);
      if (mounted) setState(() => _workoutId = id);
    } catch (e) {
      debugPrint("Error init session: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  String get _formattedTimer {
    final m = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  // Logic Finish Workout
  Future<void> _finish() async {
    if (_workoutId == null) return;
    setState(() => _isLoading = true);

    // Hitung Estimasi XP (Totalitas: Hitung berdasarkan Set yang selesai)
    int totalXP = 0;
    int totalSets = 0;
    for (var ex in _activeExercises) {
      for (var set in ex.sets) {
        if (set.isCompleted) {
          totalSets++;
          totalXP += 10; // 10 XP per set
        }
      }
    }
    if (totalSets > 0) totalXP += 50; // Bonus finish
    int points = (totalXP / 5).floor();

    await _repo.finishWorkout(_workoutId!, totalXP, points);

    if (mounted) {
      Navigator.pop(context); // Kembali ke Home
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.emoji_events, color: Colors.yellow),
          const SizedBox(width: 8),
          Text("Victory! +$totalXP XP | +$points Points"),
        ]),
        backgroundColor: AppTheme.secondaryColor,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // Tambah Exercise saat sedang latihan (Freestyle Addition)
  void _addExerciseManual() {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        builder: (ctx) => _ExercisePickerLocal(onSelect: (ex) {
              setState(() {
                _activeExercises
                    .add(ActiveExerciseModel(exercise: ex, sets: []));
              });
              Navigator.pop(ctx);
            }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Text(widget.sessionName,
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            Text(_formattedTimer,
                style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: _isLoading ? null : _finish,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("FINISH",
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)))
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
                  TextButton(
                      onPressed: _addExerciseManual,
                      child: const Text("Add First Exercise"))
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 100, top: 16),
              itemCount: _activeExercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _ActiveExerciseCard(
                  activeEx: _activeExercises[index],
                  workoutId: _workoutId,
                  repo: _repo,
                  onUpdate: () => setState(() {}),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExerciseManual,
        label: const Text("Add Exercise",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.black),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}

// --- SUB-WIDGET: KARTU EXERCISE AKTIF ---
class _ActiveExerciseCard extends StatelessWidget {
  final ActiveExerciseModel activeEx;
  final String? workoutId;
  final WorkoutRepository repo;
  final VoidCallback onUpdate;

  const _ActiveExerciseCard(
      {required this.activeEx,
      required this.workoutId,
      required this.repo,
      required this.onUpdate});

  void _addSet() {
    // Tambah set baru ke memory
    activeEx.sets.add(WorkoutSetModel(
        setNumber: activeEx.sets.length + 1,
        tier: 'D', // Default
        targetValue: activeEx.exercise.scaleType == 'static_hold'
            ? 30
            : 10 // Default value pintar
        ));
    onUpdate();
  }

  void _checkSet(WorkoutSetModel set) {
    // Optimistic Update UI
    set.isCompleted = !set.isCompleted;
    set.completedValue = set.isCompleted ? set.targetValue : null;
    onUpdate();

    // Save to DB kalau workoutId sudah ada
    if (workoutId != null) {
      repo
          .saveSet(
              workoutId: workoutId!,
              exerciseId: activeEx.exercise.id,
              set: set,
              workoutExerciseId: activeEx.workoutExerciseId)
          .then((_) {
        // Sukses simpan
      }).catchError((e) {
        debugPrint("Gagal simpan set: $e");
        // Opsional: Revert status kalau gagal
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Judul Exercise
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(activeEx.exercise.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(activeEx.exercise.targetMuscle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
                const Icon(Icons.more_horiz, color: Colors.grey)
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Header Kolom Table
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              const SizedBox(
                  width: 30,
                  child: Text("Set",
                      style: TextStyle(color: Colors.grey, fontSize: 12))),
              const Expanded(
                  child: Text("Previous",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center)),
              const SizedBox(
                  width: 60,
                  child: Text("Kg",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center)),
              SizedBox(
                  width: 60,
                  child: Text(
                      activeEx.exercise.unit == 'seconds' ? 'Secs' : 'Reps',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center)),
              const SizedBox(width: 40), // Space for Checkbox
            ]),
          ),

          // List Sets
          ...activeEx.sets.map((set) {
            final isDone = set.isCompleted;
            return Container(
              color:
                  isDone ? Colors.green.withOpacity(0.1) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                // Nomor Set
                SizedBox(
                    width: 30,
                    child: Text("${set.setNumber}",
                        style: const TextStyle(color: Colors.white))),

                // Previous Value (Placeholder)
                const Expanded(
                    child: Text("-",
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center)),

                // Input Weight (Kg)
                SizedBox(
                    width: 60,
                    height: 30,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text("${set.weightKg}",
                          style: const TextStyle(color: Colors.white)),
                    )),
                const SizedBox(width: 8),

                // Input Reps/Value
                SizedBox(
                    width: 60,
                    height: 30,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text("${set.targetValue}",
                          style: const TextStyle(color: Colors.white)),
                    )),
                const SizedBox(width: 8),

                // Checkbox Button
                InkWell(
                  onTap: () => _checkSet(set),
                  child: Container(
                    width: 32,
                    height: 30,
                    decoration: BoxDecoration(
                        color: isDone ? Colors.green : Colors.grey[800],
                        borderRadius: BorderRadius.circular(4)),
                    child:
                        const Icon(Icons.check, size: 16, color: Colors.white),
                  ),
                )
              ]),
            );
          }).toList(),

          // Add Set Button
          InkWell(
            onTap: _addSet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: const Text("+ Add Set",
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }
}

// Picker untuk Halaman Aktif (Simpel)
class _ExercisePickerLocal extends StatelessWidget {
  final Function(ExerciseModel) onSelect;
  const _ExercisePickerLocal({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 400,
      child: FutureBuilder<List<ExerciseModel>>(
        future: WorkoutRepository().getExerciseLibrary(),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snap.data!.length,
            itemBuilder: (ctx, i) => ListTile(
              title: Text(snap.data![i].name,
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text(snap.data![i].targetMuscle,
                  style: const TextStyle(color: Colors.grey)),
              onTap: () => onSelect(snap.data![i]),
            ),
          );
        },
      ),
    );
  }
}
