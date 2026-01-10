import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/features/task/data/task_model.dart';

class TaskRepository {
  // Singleton Pattern
  static final TaskRepository _instance = TaskRepository._internal();
  factory TaskRepository() => _instance;
  TaskRepository._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  String get _userId => _supabase.auth.currentUser!.id;

  // 1. STREAM TASKS (Raw Data dari Supabase)
  Stream<List<TaskModel>> getTasksStream() {
    return _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('is_completed', ascending: true) // Belum selesai di atas
        .order('priority', ascending: false) // High priority di atas
        .map((data) => data.map((e) => TaskModel.fromJson(e)).toList());
  }

  // 2. TOGGLE TASK (Complete/Undo + XP Logic)
  Future<Map<String, dynamic>> toggleTask(
      TaskModel task, bool isCompleted) async {
    try {
      // A. Update Task Status
      await _supabase.from('tasks').update({
        'is_completed': isCompleted,
        'current_value': isCompleted ? task.targetValue : 0,
        'last_completed_at':
            isCompleted ? DateTime.now().toUtc().toIso8601String() : null,
      }).eq('id', task.id);

      // B. Hitung Reward Logic
      int xpReward = 0;
      int pointsReward = 0;
      int multiplier = task.frequency == 'Weekly' ? 2 : 1;

      switch (task.priority) {
        case 'High':
          xpReward = 50 * multiplier;
          pointsReward = 15 * multiplier;
          break;
        case 'Medium':
          xpReward = 30 * multiplier;
          pointsReward = 10 * multiplier;
          break;
        default: // Low
          xpReward = 10 * multiplier;
          pointsReward = 5 * multiplier;
      }

      if (!isCompleted) {
        xpReward = -xpReward;
        pointsReward = -pointsReward;
      }

      // C. Insert Log (Trigger XP/Gold di DB)
      await _supabase.from('point_logs').insert({
        'user_id': _userId,
        'xp_change': xpReward,
        'points_change': pointsReward,
        'source_type': 'task',
        'description':
            isCompleted ? 'Completed: ${task.title}' : 'Undo: ${task.title}',
      });

      return {'xp': xpReward, 'points': pointsReward};
    } catch (e) {
      throw Exception('Gagal update task: $e');
    }
  }

  // 3. SMART GLOBAL RESET (Client-Side Logic) 🌍
  Future<int> checkAndResetDailyTasks() async {
    try {
      final now = DateTime.now();
      // Format YYYY-MM-DD lokal
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // debugPrint("🔍 Checking Reset for: $todayStr");

      // A. Cek Profil: Kapan terakhir reset?
      final profile = await _supabase
          .from('profiles')
          .select('last_daily_reset')
          .eq('id', _userId)
          .maybeSingle();

      if (profile == null) return 0; // Safety check

      final lastReset = profile['last_daily_reset'] as String?;

      // LOGIC UTAMA:
      // Jika 'last_daily_reset' SAMA dengan hari ini, berarti SUDAH BERES.
      // Tidak perlu reset lagi, tidak perlu update lagi.
      if (lastReset == todayStr) {
        // debugPrint("✅ Hari ini sudah reset ($todayStr). Skip.");
        return 0;
      }

      // B. Jika BEDA (Berarti hari baru atau user baru), LAKUKAN RESET.
      debugPrint(
          "⏳ Memulai Daily Reset (Last: $lastReset vs Today: $todayStr)...");

      // 1. Update tanggal reset di profil DULUAN.
      // Ini penting agar jika user mengerjakan tugas setelah ini,
      // sistem tau bahwa hari ini sudah "ditandai" dan tidak akan mereset lagi.
      await _supabase
          .from('profiles')
          .update({'last_daily_reset': todayStr}).eq('id', _userId);

      // 2. Baru reset task-nya
      await _supabase
          .from('tasks')
          .update({
            'is_completed': false,
            'current_value': 0,
            'last_completed_at': null,
          })
          .eq('user_id', _userId)
          .eq('frequency', 'Daily');

      debugPrint("🎉 Daily Reset Selesai & Tanggal Updated!");
      return 1; // Return 1 triggrer notifikasi "Good Morning"
    } catch (e) {
      debugPrint("❌ Error Reset: $e");
      return 0;
    }
  }

  // 4. GENERATE TASKS FROM LIBRARY
  Future<int> generateTasksFromLibrary(String frequency) async {
    final templates = await _supabase
        .from('task_library')
        .select()
        .eq('default_frequency', frequency);

    if (templates.isEmpty) return 0;

    final List<Map<String, dynamic>> newTasks = templates
        .map((t) => {
              'user_id': _userId,
              'title': t['title'],
              'category': t['category'],
              'priority': t['default_priority'],
              'frequency': frequency,
              'target_value': t['default_target_value'],
              'unit': t['default_unit'],
              'current_value': 0,
              'is_completed': false,
            })
        .toList();

    await _supabase.from('tasks').insert(newTasks);
    return newTasks.length;
  }

  // 5. CRUD Helper (Create/Update/Delete)
  Future<void> saveTask(Map<String, dynamic> data, {String? docId}) async {
    data['user_id'] = _userId;
    if (docId != null) {
      // Update
      await _supabase.from('tasks').update(data).eq('id', docId);
    } else {
      // Create
      data['current_value'] = 0;
      data['is_completed'] = false;
      await _supabase.from('tasks').insert(data);
    }
  }

  Future<void> deleteTask(String taskId) async {
    await _supabase.from('tasks').delete().eq('id', taskId);
  }
}
