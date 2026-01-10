import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_tracker/features/task/data/task_model.dart';

class TaskRepository {
  static final TaskRepository _instance = TaskRepository._internal();
  factory TaskRepository() => _instance;
  TaskRepository._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  String get _userId => _supabase.auth.currentUser!.id;

  // 1. STREAM TASKS (Raw Data)
  Stream<List<TaskModel>> getTasksStream() {
    return _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('is_completed', ascending: true)
        .order('priority', ascending: false) // High diatas
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
            isCompleted ? DateTime.now().toIso8601String() : null,
      }).eq('id', task.id);

      // B. Hitung Reward Logic (Disalin dari kodemu)
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

      // C. Insert Log
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

  // 3. SMART REFRESH (Reset Daily Tasks)
  Future<int> refreshDailyTasks() async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('user_id', _userId)
          .eq('frequency', 'Daily')
          .eq('is_completed', true);

      final now = DateTime.now();
      final List<String> idsToReset = [];

      for (var task in response) {
        final completedAtStr = task['last_completed_at'];
        if (completedAtStr == null) continue;
        final completedAt = DateTime.parse(completedAtStr).toLocal();

        final isSameDay = completedAt.year == now.year &&
            completedAt.month == now.month &&
            completedAt.day == now.day;

        if (!isSameDay) {
          idsToReset.add(task['id']);
        }
      }

      if (idsToReset.isNotEmpty) {
        // Syntax .filter('id', 'in', list) sesuai Supabase v2
        await _supabase.from('tasks').update({
          'is_completed': false,
          'current_value': 0,
          'last_completed_at': null,
        }).filter('id', 'in', idsToReset);
      }

      return idsToReset.length;
    } catch (e) {
      debugPrint("Refresh Error: $e");
      return 0;
    }
  }

  // 4. GENERATE FROM LIBRARY
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

  // 5. CRUD: Create / Update / Delete
  Future<void> saveTask(Map<String, dynamic> data, {String? docId}) async {
    data['user_id'] = _userId; // Ensure user ID
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
