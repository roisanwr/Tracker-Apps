import 'package:flutter/material.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/task/data/task_model.dart';
import 'package:workout_tracker/features/task/data/task_repository.dart';

class TaskView extends StatefulWidget {
  const TaskView({super.key});

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  // Inisialisasi Repository
  final TaskRepository _repository = TaskRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Background Gelap
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Daily Missions",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace', // Font ala Game
              ),
            ),
            const SizedBox(height: 16),

            // LIST TASK (STREAM)
            Expanded(
              child: StreamBuilder<List<TaskModel>>(
                stream: _repository.getTasksStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }

                  final tasks = snapshot.data!;

                  return ListView.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _buildRpgTaskCard(task);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Tombol Tambah Misi (Floating Action Button)
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        onPressed: () {
          // TODO: Buka Dialog Tambah Task
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Fitur Tambah Misi belum dibuat")),
          );
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  // WIDGET KARTU MISI ALA RPG
  Widget _buildRpgTaskCard(TaskModel task) {
    final bool isDone = task.isCompleted;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? Colors.green.withOpacity(0.5)
              : Colors.grey.withOpacity(0.3),
        ),
        boxShadow: isDone
            ? [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 8)]
            : [],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Checkbox(
          value: isDone,
          activeColor: AppTheme.primaryColor,
          onChanged: (val) async {
            if (val == true) {
              await _repository.completeTask(task);
              // Feedback Suara atau Getar bisa ditaruh disini
            }
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            color: isDone ? Colors.grey : Colors.white,
            decoration: isDone ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.description,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 8),
            // REWARD BADGES
            Row(
              children: [
                _buildBadge(
                    Icons.star, "+${task.xpReward} XP", Colors.purpleAccent),
                const SizedBox(width: 8),
                _buildBadge(
                    Icons.monetization_on, "+${task.goldReward}", Colors.amber),
              ],
            )
          ],
        ),
        trailing: _buildDifficultyTag(task.difficulty),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDifficultyTag(String difficulty) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'hard':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      default:
        color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        difficulty,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined,
              size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text("No Active Missions", style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}
