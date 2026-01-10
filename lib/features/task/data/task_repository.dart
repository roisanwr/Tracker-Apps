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

  // 1. STREAM TASKS
  Stream<List<TaskModel>> getTasksStream() {
    return _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('is_completed', ascending: true)
        .order('priority', ascending: false)
        .map((data) => data.map((e) => TaskModel.fromJson(e)).toList());
  }

  // 2. TOGGLE TASK (Pure Client Update + Optimistic UI Calc)
  Future<Map<String, dynamic>> toggleTask(
      TaskModel task, bool isCompleted) async {
    try {
      // A. Update Task Status ke Server
      // Kita CUKUP update statusnya saja.
      // Trigger di SQL 'on_task_completion' yang akan otomatis:
      // 1. Mendeteksi perubahan
      // 2. Menghitung poin
      // 3. Menulis ke point_logs
      await _supabase.from('tasks').update({
        'is_completed': isCompleted,
        'current_value': isCompleted ? task.targetValue : 0,
        'last_completed_at':
            isCompleted ? DateTime.now().toUtc().toIso8601String() : null,
      }).eq('id', task.id);

      // B. OPTIMISTIC UI CALCULATION (Hanya untuk Tampilan!) 🎨
      // Kita hitung lokal supaya UI bisa langsung kasih feedback "+50 XP"
      // TANPA harus nunggu server balas atau fetch ulang log.
      // Data ini TIDAK disimpan ke DB dari sini.

      int xpReward = 0;
      int pointsReward = 0;
      int multiplier = task.frequency == 'Weekly' ? 2 : 1;

      switch (task.priority) {
        case 'High':
          xpReward = 50;
          pointsReward = 15;
          break;
        case 'Medium':
          xpReward = 30;
          pointsReward = 10;
          break;
        default: // Low
          xpReward = 10;
          pointsReward = 5;
      }

      // Nerf Custom Task (Sinkron dengan Logic SQL)
      if (task.isCustom) {
        xpReward = (xpReward / 2).floor();
        pointsReward = (pointsReward / 2).floor();
        if (xpReward < 1) xpReward = 1;
        if (pointsReward < 1) pointsReward = 1;
      }

      xpReward = xpReward * multiplier;
      pointsReward = pointsReward * multiplier;

      if (!isCompleted) {
        xpReward = -xpReward;
        pointsReward = -pointsReward;
      }

      // 🛑 STOP! JANGAN INSERT KE point_logs DARI SINI!
      // Biarkan Trigger SQL yang bekerja.

      // Return data estimasi ini cuma buat Snackbar/UI
      return {'xp': xpReward, 'points': pointsReward};
    } catch (e) {
      throw Exception('Gagal update task: $e');
    }
  }

  // 3. SMART GLOBAL RESET (DISABLED)
  // Server Side Authority (via pg_cron)
  Future<int> checkAndResetDailyTasks() async {
    debugPrint("🤖 Daily Reset ditangani oleh Server Trigger. Client idle.");
    return 0;
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
              'is_custom': false, // ✨ Ini dari Library, jadi bukan Custom
            })
        .toList();

    await _supabase.from('tasks').insert(newTasks);
    return newTasks.length;
  }

  // 5. CRUD Helper
  Future<void> saveTask(Map<String, dynamic> data, {String? docId}) async {
    data['user_id'] = _userId;
    // Pastikan is_custom tersetting jika tidak ada
    if (!data.containsKey('is_custom')) {
      // Jika user bikin manual lewat form tambah task, anggap Custom
      data['is_custom'] = true;
    }

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
