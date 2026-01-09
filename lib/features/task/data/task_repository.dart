import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/features/task/data/task_model.dart';

class TaskRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Mendapatkan User ID saat ini
  String get _userId => _supabase.auth.currentUser!.id;

  // 1. AMBIL DATA (STREAM)
  // Mengambil list task secara real-time
  Stream<List<TaskModel>> getTasksStream() {
    return _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId) // Filter hanya task milik user ini
        .order('created_at')
        .map((data) => data.map((json) => TaskModel.fromJson(json)).toList());
  }

  // 2. SELESAIKAN MISI (LOGIC RPG)
  // Mengupdate status task & Menambahkan XP/Gold ke User
  Future<void> completeTask(TaskModel task) async {
    try {
      // Jika task sudah selesai, jangan diproses lagi (atau buat logic uncheck kalau mau)
      if (task.isCompleted) return;

      // A. Tandai Task sebagai selesai di Database
      await _supabase.from('tasks').update({
        'is_completed': true,
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', task.id);

      // B. Update Profile User (Tambah XP & Gold)
      // Kita pakai RPC (Remote Procedure Call) atau query update biasa.
      // Disini saya pakai cara manual fetch-update agar logika terlihat jelas di Dart.

      final profileResponse =
          await _supabase.from('profiles').select().eq('id', _userId).single();

      final int currentXp = profileResponse['current_xp'] ?? 0;
      final int currentPoints = profileResponse['current_points'] ?? 0;

      await _supabase.from('profiles').update({
        'current_xp': currentXp + task.xpReward,
        'current_points': currentPoints + task.goldReward,
      }).eq('id', _userId);
    } catch (e) {
      throw Exception('Gagal menyelesaikan misi: $e');
    }
  }

  // 3. RESET HARIAN (AUTO-RESET)
  // Logic untuk mereset task harian (bisa dipanggil saat aplikasi dibuka)
  Future<void> resetDailyTasks() async {
    // Cari task 'Daily' yang sudah selesai, lalu reset jadi false
    await _supabase
        .from('tasks')
        .update({'is_completed': false})
        .eq('user_id', _userId)
        .eq('frequency', 'Daily')
        .eq('is_completed', true);
  }
}
