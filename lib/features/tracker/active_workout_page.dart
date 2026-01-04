import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';

class ActiveWorkoutPage extends StatefulWidget {
  // ⚡ TERIMA PAKET DATA DARI JADWAL (Opsional)
  final List<Map<String, dynamic>>? initialExercises;

  const ActiveWorkoutPage({super.key, this.initialExercises});

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  // ⏱️ TIMER STATE
  Timer? _timer;
  int _secondsElapsed = 0;

  // 🏋️ WORKOUT DATA STATE
  final List<Map<String, dynamic>> _activeExercises = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // ⚡ LOAD INITIAL DATA: Kalau ada kiriman dari jadwal, masukkan ke list!
    if (widget.initialExercises != null) {
      _activeExercises.addAll(widget.initialExercises!);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  String _formatTime(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // 1. ADD EXERCISE MODAL (Pilih dari Library)
  void _showExercisePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => _ExercisePickerSheet(
          scrollController: controller,
          onSelect: (exercise) {
            setState(() {
              _activeExercises.add({
                'exercise': exercise,
                'sets': <Map<String, dynamic>>[
                  // Default Set 1 kosong
                  {'reps': '', 'weight': '', 'is_completed': false}
                ]
              });
            });
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  // 2. FINISH WORKOUT LOGIC (Simpan ke DB)
  Future<void> _finishWorkout() async {
    if (_activeExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Workout kosong! Tambah latihan dulu.")));
      return;
    }

    setState(() => _isSaving = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final endTime = DateTime.now();
    final startTime = endTime.subtract(Duration(seconds: _secondsElapsed));

    try {
      // A. Insert Header Workout
      final workoutRes = await Supabase.instance.client
          .from('workouts')
          .insert({
            'user_id': userId,
            'started_at': startTime.toIso8601String(),
            'ended_at': endTime.toIso8601String(),
            'status': 'completed',
          })
          .select()
          .single();

      final workoutId = workoutRes['id'];
      int totalXpGained = 0;

      // B. Loop Exercises & Sets
      for (var activeEx in _activeExercises) {
        final exerciseLib = activeEx['exercise'];
        final sets = activeEx['sets'] as List<Map<String, dynamic>>;

        // Insert Workout Exercise Relationship
        final weRes = await Supabase.instance.client
            .from('workout_exercises')
            .insert({
              'workout_id': workoutId,
              'exercise_id': exerciseLib['id'],
            })
            .select()
            .single();

        final workoutExerciseId = weRes['id'];

        // Insert Sets
        for (int i = 0; i < sets.length; i++) {
          final set = sets[i];

          // Konversi input string ke angka
          int reps = int.tryParse(set['reps'].toString()) ?? 0;
          double weight = double.tryParse(set['weight'].toString()) ?? 0.0;
          String tier =
              set['tier'] ?? 'D'; // Ambil tier kalau ada (dari jadwal)

          await Supabase.instance.client.from('sets').insert({
            'workout_exercise_id': workoutExerciseId,
            'set_number': i + 1,
            'tier': tier,
            'target_value': 0, // Manual mode
            'completed_value': reps,
            'weight_kg': weight,
            'is_completed': set['is_completed'] ?? false,
          });

          // HITUNG XP SEDERHANA 🧠
          // Rumus: 1 Rep = 1 XP. Bonus beban = Berat / 10.
          if (set['is_completed'] == true) {
            totalXpGained += reps;
            if (weight > 0) totalXpGained += (weight ~/ 10);
          }
        }
      }

      // C. Update Total XP di Workout & Profile
      await Supabase.instance.client
          .from('workouts')
          .update({'total_xp_earned': totalXpGained}).eq('id', workoutId);

      // Log ke Point Logs (Trigger Profile Update)
      await Supabase.instance.client.from('point_logs').insert({
        'user_id': userId,
        'xp_change': totalXpGained,
        'points_change': (totalXpGained / 5).floor(), // 5 XP = 1 Gold
        'source_type': 'workout',
        'description': 'Workout Session (${_secondsElapsed ~/ 60} mins)',
      });

      if (mounted) {
        Navigator.pop(context); // Tutup halaman workout
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Workout Finish! +$totalXpGained XP"),
            backgroundColor: AppTheme.secondaryColor));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error saving: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // HEADER: TIMER & FINISH BUTTON
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: () {
            // Konfirmasi batal workout
            showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      title: const Text("Quit Session?",
                          style: TextStyle(color: Colors.white)),
                      content: const Text("Progress will be lost.",
                          style: TextStyle(color: Colors.grey)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel")),
                        TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pop(context);
                            },
                            child: const Text("Quit",
                                style: TextStyle(color: Colors.red))),
                      ],
                    ));
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ACTIVE SESSION",
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1.5)),
            Text(_formatTime(_secondsElapsed),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'monospace')),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _finishWorkout,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.black),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text("FINISH",
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),

      // BODY: EXERCISE LIST
      body: _activeExercises.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fitness_center,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("Start by adding an exercise",
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _showExercisePicker,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.black),
                      child: const Text("Add Exercise"))
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount:
                  _activeExercises.length + 1, // +1 untuk tombol Add di bawah
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                if (index == _activeExercises.length) {
                  // Tombol Add Exercise di paling bawah
                  return OutlinedButton(
                    onPressed: _showExercisePicker,
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.all(16)),
                    child: const Text("+ ADD EXERCISE",
                        style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold)),
                  );
                }

                final activeExercise = _activeExercises[index];
                return _buildExerciseCard(index, activeExercise);
              },
            ),
    );
  }

  // WIDGET: CARD LATIHAN (Berisi Daftar Set)
  Widget _buildExerciseCard(
      int exerciseIndex, Map<String, dynamic> activeExercise) {
    final exerciseData = activeExercise['exercise'];
    final sets = activeExercise['sets'] as List<Map<String, dynamic>>;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Nama Latihan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(exerciseData['name'],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                onPressed: () {
                  // Opsional: Remove Exercise
                  setState(() {
                    _activeExercises.removeAt(exerciseIndex);
                  });
                },
              )
            ],
          ),

          // Header Kolom Set
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                SizedBox(
                    width: 30,
                    child: Text("SET",
                        style: TextStyle(color: Colors.grey, fontSize: 10))),
                SizedBox(width: 16),
                Expanded(
                    child: Text("KG",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 10))),
                SizedBox(width: 16),
                Expanded(
                    child: Text("REPS",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 10))),
                SizedBox(
                    width: 40,
                    child: Icon(Icons.check, size: 16, color: Colors.grey)),
              ],
            ),
          ),

          // Daftar Set
          ...List.generate(sets.length, (setIndex) {
            final set = sets[setIndex];
            final bool isCompleted = set['is_completed'];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.secondaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4)),
              child: Row(
                children: [
                  // Nomor Set
                  SizedBox(
                      width: 30,
                      child: Center(
                          child: Text("${setIndex + 1}",
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 16),

                  // Input Berat (KG)
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4)),
                      child: TextField(
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(bottom: 12)),
                        onChanged: (val) => set['weight'] = val,
                        controller: TextEditingController(text: set['weight'])
                          ..selection = TextSelection.fromPosition(
                              TextPosition(offset: set['weight'].length)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Input Repetisi
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4)),
                      child: TextField(
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(bottom: 12)),
                        onChanged: (val) => set['reps'] = val,
                        controller: TextEditingController(text: set['reps'])
                          ..selection = TextSelection.fromPosition(
                              TextPosition(offset: set['reps'].length)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Checkbox Selesai
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: isCompleted,
                      activeColor: AppTheme.secondaryColor,
                      checkColor: Colors.black,
                      onChanged: (val) {
                        setState(() {
                          set['is_completed'] = val;
                        });
                      },
                    ),
                  )
                ],
              ),
            );
          }),

          // Tombol Add Set
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  // Copy data dari set sebelumnya biar gampang
                  String prevReps = '';
                  String prevWeight = '';
                  String prevTier = 'D'; // Default

                  if (sets.isNotEmpty) {
                    prevReps = sets.last['reps'];
                    prevWeight = sets.last['weight'];
                    prevTier = sets.last['tier'] ?? 'D';
                  }

                  sets.add({
                    'reps': prevReps,
                    'weight': prevWeight,
                    'tier': prevTier,
                    'is_completed': false
                  });
                });
              },
              child: const Text("+ Add Set",
                  style: TextStyle(color: AppTheme.primaryColor)),
            ),
          )
        ],
      ),
    );
  }
}

// =============================================================================
// 📋 BOTTOM SHEET: PILIH LATIHAN
// =============================================================================
class _ExercisePickerSheet extends StatelessWidget {
  final ScrollController scrollController;
  final Function(Map<String, dynamic>) onSelect;

  const _ExercisePickerSheet(
      {required this.scrollController, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Select Exercise",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('exercise_library')
                  .stream(primaryKey: ['id']).order('name', ascending: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor));

                final exercises = snapshot.data!;
                return ListView.separated(
                  controller: scrollController,
                  itemCount: exercises.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final ex = exercises[index];
                    return ListTile(
                      title: Text(ex['name'],
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                          "${ex['target_muscle']} • ${ex['scale_type']}",
                          style: const TextStyle(color: Colors.grey)),
                      onTap: () => onSelect(ex),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
