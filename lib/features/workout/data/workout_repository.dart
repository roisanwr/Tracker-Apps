import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/features/workout/data/workout_models.dart';

class WorkoutRepository {
  static final WorkoutRepository _instance = WorkoutRepository._internal();
  factory WorkoutRepository() => _instance;
  WorkoutRepository._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  String get _userId => _supabase.auth.currentUser!.id;

  // ===========================================================================
  // 📅 JADWAL & TEMPLATE (Weekly Schedule)
  // ===========================================================================

  /// 1. Pastikan Template Mon-Sun tersedia di DB
  Future<void> ensureWeeklyTemplates() async {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final existing = await _supabase
        .from('workouts')
        .select()
        .eq('user_id', _userId)
        .eq('status', 'template');

    for (var day in days) {
      // Cek apakah sudah ada template untuk hari ini
      final exists = existing.any((w) => w['notes'] == day);
      if (!exists) {
        await _supabase.from('workouts').insert({
          'user_id': _userId,
          'status': 'template',
          'notes': day,
          'started_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }
  }

  /// 2. Ambil Latihan untuk Hari Tertentu (misal: 'Mon')
  Future<List<ExerciseModel>> getTemplateExercises(String dayName) async {
    // A. Cari ID Workout Template untuk hari itu
    // 🔥 FIX: Tambah .limit(1) biar kalau ada duplikat gak error
    final template = await _supabase
        .from('workouts')
        .select('id')
        .eq('user_id', _userId)
        .eq('status', 'template')
        .eq('notes', dayName)
        .limit(1) // <--- PENYELAMAT! Ambil 1 aja.
        .maybeSingle();

    if (template == null) return [];

    // B. Ambil Exercise yang terhubung ke Template itu
    final response = await _supabase
        .from('workout_exercises')
        .select('exercise:exercise_library(*)')
        .eq('workout_id', template['id']);

    return (response as List).map((item) {
      final exData = item['exercise'] as Map<String, dynamic>;
      return ExerciseModel.fromJson(exData);
    }).toList();
  }

  /// 3. Tambah Latihan ke Template Hari Ini
  Future<void> addExerciseToTemplate(
      String dayName, ExerciseModel exercise) async {
    // 🔥 FIX: Tambah .limit(1) juga disini
    final template = await _supabase
        .from('workouts')
        .select('id')
        .eq('user_id', _userId)
        .eq('status', 'template')
        .eq('notes', dayName)
        .limit(1) // <--- PENYELAMAT!
        .single();

    // Insert relasi
    await _supabase.from('workout_exercises').insert({
      'workout_id': template['id'],
      'exercise_id': exercise.id,
    });
  }

  /// 4. Hapus Latihan dari Template
  Future<void> removeExerciseFromTemplate(
      String dayName, String exerciseId) async {
    // 🔥 FIX: Tambah .limit(1) juga disini
    final template = await _supabase
        .from('workouts')
        .select('id')
        .eq('user_id', _userId)
        .eq('status', 'template')
        .eq('notes', dayName)
        .limit(1) // <--- PENYELAMAT!
        .single();

    await _supabase
        .from('workout_exercises')
        .delete()
        .eq('workout_id', template['id'])
        .eq('exercise_id', exerciseId);
  }

  // ===========================================================================
  // 🏋️ WORKOUT SESSION (Active)
  // ===========================================================================

  /// 5. Mulai Sesi Workout Baru (Real-time)
  Future<String> startActiveWorkout(String sessionName) async {
    final response = await _supabase
        .from('workouts')
        .insert({
          'user_id': _userId,
          'status': 'in_progress',
          'notes': sessionName,
          'started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return response['id'];
  }

  /// 6. Simpan/Update Set (Logic Pintar)
  Future<void> saveSet({
    required String workoutId,
    required String exerciseId,
    required WorkoutSetModel set,
    String? workoutExerciseId,
  }) async {
    String weId = workoutExerciseId ?? '';

    // A. Pastikan Relasi (Active Session -> Exercise) ada
    if (weId.isEmpty) {
      // 🔥 FIX: Tambah .limit(1) biar aman
      final existing = await _supabase
          .from('workout_exercises')
          .select('id')
          .eq('workout_id', workoutId)
          .eq('exercise_id', exerciseId)
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        weId = existing['id'];
      } else {
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

    // B. Upsert Set
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
      set.id = res['id'];
    }
  }

  /// 7. Selesai Workout & Hitung XP
  Future<void> finishWorkout(
      String workoutId, int totalXP, int totalPoints) async {
    await _supabase.from('workouts').update({
      'status': 'completed',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'total_xp_earned': totalXP,
      'total_points_earned': totalPoints,
    }).eq('id', workoutId);

    await _supabase.from('point_logs').insert({
      'user_id': _userId,
      'xp_change': totalXP,
      'points_change': totalPoints,
      'source_type': 'workout',
      'description': 'Workout Session Completed',
    });
  }

  // ===========================================================================
  // 📚 LIBRARY & CUSTOM EXERCISE
  // ===========================================================================

  /// 8. Ambil Semua Library
  Future<List<ExerciseModel>> getExerciseLibrary() async {
    final response =
        await _supabase.from('exercise_library').select().order('name');
    return (response as List).map((e) => ExerciseModel.fromJson(e)).toList();
  }

  /// 9. Buat Latihan Custom
  Future<ExerciseModel> createCustomExercise(
      String name, String type, String muscle) async {
    String unit = 'reps';
    if (type == 'static_hold') unit = 'seconds';
    if (type == 'cardio_run') unit = 'meters';

    final response = await _supabase
        .from('exercise_library')
        .insert({
          'name': name,
          'scale_type': type,
          'target_muscle': muscle,
          'created_by': _userId,
          'measurement_unit': unit,
        })
        .select()
        .single();

    return ExerciseModel.fromJson(response);
  }
}
