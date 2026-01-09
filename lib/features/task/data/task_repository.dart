import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/features/task/data/task_model.dart';

class TaskRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _userId => _supabase.auth.currentUser!.id;

  // 1. AMBIL TASK (STREAM)
  Stream<List<TaskModel>> getTasksStream() {
    return _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('is_completed', ascending: true) // Yang belum selesai di atas
        .order('created_at')
        .map<List<TaskModel>>((event) {
          final list = event as List<dynamic>?;
          if (list == null) return <TaskModel>[];
          return list
              .map((e) =>
                  TaskModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
  }

  // 2. SELESAIKAN MISI (INSERT KE LOG)
  Future<void> completeTask(TaskModel task) async {
    try {
      if (task.isCompleted) return; // Cegah double click

      debugPrint("⏳ Completing task: ${task.title}");

      // A. Update Status Task di Database
      await _supabase.from('tasks').update({
        'is_completed': true,
        'current_value': task.targetValue, // Langsung set max
        'last_completed_at': DateTime.now().toIso8601String(),
      }).eq('id', task.id);

      // B. Insert ke Point Logs (PENTING! Ini trigger buat nambah XP & Gold)
      await _supabase.from('point_logs').insert({
        'user_id': _userId,
        'xp_change': task.xpReward, // Ambil dari Getter Model
        'points_change': task.goldReward, // Ambil dari Getter Model
        'source_type': 'task',
        'description': 'Completed: ${task.title}',
      });

      debugPrint("✅ Task selesai & Log tercatat!");
    } catch (e) {
      debugPrint("❌ ERROR completeTask: $e");
      throw Exception('Gagal menyelesaikan misi: $e');
    }
  }

  // 3. UNDO MISI (BATALKAN & TARIK XP)
  Future<void> undoTask(TaskModel task) async {
    try {
      if (!task.isCompleted) return;

      debugPrint("⏳ Undoing task: ${task.title}");

      // A. Kembalikan Status Task
      await _supabase.from('tasks').update({
        'is_completed': false,
        'current_value': 0,
        'last_completed_at': null,
      }).eq('id', task.id);

      // B. Insert Log Negatif (Kurangi XP & Gold)
      await _supabase.from('point_logs').insert({
        'user_id': _userId,
        'xp_change': -task.xpReward, // MINUS
        'points_change': -task.goldReward, // MINUS
        'source_type': 'task',
        'description': 'Undo: ${task.title}',
      });

      debugPrint("✅ Task di-undo & XP ditarik!");
    } catch (e) {
      debugPrint("❌ ERROR undoTask: $e");
      throw Exception('Gagal membatalkan misi: $e');
    }
  }
}
