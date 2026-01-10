import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/features/workout/data/workout_models.dart';

class WorkoutRepository {
  static final WorkoutRepository _instance = WorkoutRepository._internal();
  factory WorkoutRepository() => _instance;
  WorkoutRepository._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  String get _userId => _supabase.auth.currentUser!.id;

  // 📚 1. GET EXERCISE LIBRARY
  Future<List<ExerciseModel>> getExercises() async {
    final response = await _supabase
        .from('exercise_library')
        .select()
        .order('name', ascending: true);

    return (response as List).map((e) => ExerciseModel.fromJson(e)).toList();
  }

  // ➕ 2. CREATE CUSTOM EXERCISE
  Future<void> createCustomExercise(
      String name, String muscle, String type) async {
    await _supabase.from('exercise_library').insert({
      'name': name,
      'target_muscle': muscle,
      'scale_type': type,
      'created_by': _userId,
      'measurement_unit': _getUnitByType(type),
    });
  }

  String _getUnitByType(String type) {
    if (type == 'static_hold') return 'seconds';
    if (type == 'cardio_run') return 'meters';
    return 'reps';
  }

  // 🚀 3. START WORKOUT (Create Session)
  Future<String> startWorkout({String? templateName}) async {
    final response = await _supabase
        .from('workouts')
        .insert({
          'user_id': _userId,
          'status': 'in_progress',
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'notes': templateName ?? 'Freestyle Workout',
        })
        .select()
        .single();

    return response['id'];
  }

  // 💾 4. SAVE SET LOG
  // Ini fungsi pintar: Kalau set belum ada di DB, dia Insert. Kalau udah ada, dia Update.
  Future<void> saveSet({
    required String workoutId,
    required String exerciseId,
    required WorkoutSetModel set,
    String? workoutExerciseId, // Kalau null, berarti exercise baru dimasukin
  }) async {
    // A. Pastikan Relasi Workout-Exercise ada dulu
    String weId = workoutExerciseId ?? '';
    if (weId.isEmpty) {
      // Cek dulu udah ada belum
      final existing = await _supabase
          .from('workout_exercises')
          .select('id')
          .eq('workout_id', workoutId)
          .eq('exercise_id', exerciseId)
          .maybeSingle();

      if (existing != null) {
        weId = existing['id'];
      } else {
        // Create baru
        final newWe = await _supabase
            .from('workout_exercises')
            .insert({
              'workout_id': workoutId,
              'exercise_id': exerciseId,
            })
            .select()
            .single();
        weId = newWe['id'];
      }
    }

    // B. Simpan Set
    final setData = {
      'workout_exercise_id': weId,
      'set_number': set.setNumber,
      'tier': set.tier,
      'target_value': set.targetValue,
      'completed_value': set.completedValue,
      'weight_kg': set.weightKg,
      'is_completed': set.isCompleted,
    };

    if (set.id != null) {
      await _supabase.from('sets').update(setData).eq('id', set.id!);
    } else {
      final res =
          await _supabase.from('sets').insert(setData).select().single();
      set.id = res['id']; // Update ID lokal
    }
  }

  // 🏁 5. FINISH WORKOUT
  Future<Map<String, int>> finishWorkout(
      String workoutId, int totalXP, int totalPoints) async {
    await _supabase.from('workouts').update({
      'status': 'completed',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'total_xp_earned': totalXP,
      'total_points_earned': totalPoints,
    }).eq('id', workoutId);

    // Insert Log Global juga biar balance nambah
    await _supabase.from('point_logs').insert({
      'user_id': _userId,
      'xp_change': totalXP,
      'points_change': totalPoints,
      'source_type': 'workout',
      'description': 'Workout Session Completed',
    });

    return {'xp': totalXP, 'points': totalPoints};
  }
}
