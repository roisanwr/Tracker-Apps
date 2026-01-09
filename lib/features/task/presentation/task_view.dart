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
  final TaskRepository _repository = TaskRepository();

  // Handle Checkbox Tap
  Future<void> _handleTaskToggle(TaskModel task, bool? value) async {
    if (value == null) return;

    try {
      // UX: Tampilkan loading kecil atau feedback haptic (opsional)

      if (value == true) {
        // --- SELESAIKAN MISI ---
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Completing ${task.title}..."),
            duration: const Duration(milliseconds: 500),
            backgroundColor: Colors.blueGrey,
          ),
        );

        await _repository.completeTask(task);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Mission Complete! +${task.xpReward} XP"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // --- UNDO MISI (BATALKAN) ---
        await _repository.undoTask(task);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Undone. XP Reverted."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: Pastikan internet lancar."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                fontFamily: 'monospace',
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
                  if (snapshot.hasError) {
                    return Center(
                        child: Text("Error: ${snapshot.error}",
                            style: const TextStyle(color: Colors.red)));
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Fitur Tambah Misi belum dibuat")),
          );
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildRpgTaskCard(TaskModel task) {
    final bool isDone = task.isCompleted;

    // Tentukan warna border berdasarkan Priority
    Color priorityColor = Colors.grey;
    if (task.priority == 'High') priorityColor = Colors.redAccent;
    if (task.priority == 'Medium') priorityColor = Colors.amber;
    if (task.priority == 'Low') priorityColor = Colors.green;

    return Opacity(
      opacity: isDone ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone ? Colors.green.withOpacity(0.5) : Colors.white10,
          ),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

          // CHECKBOX
          leading: Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: isDone,
              activeColor: AppTheme.primaryColor,
              checkColor: Colors.black,
              side: BorderSide(color: Colors.grey[600]!, width: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              onChanged: (val) => _handleTaskToggle(task, val),
            ),
          ),

          // JUDUL & DESKRIPSI
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
              const SizedBox(height: 4),
              // Badge Category & Value
              Row(
                children: [
                  _buildSmallTag(task.category, Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text(
                    "${task.targetValue} ${task.unit}",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // REWARD BADGES (Dihitung dari Getter Model)
              Row(
                children: [
                  _buildBadge(
                      Icons.star, "+${task.xpReward} XP", Colors.purpleAccent),
                  const SizedBox(width: 8),
                  _buildBadge(Icons.monetization_on, "+${task.goldReward}",
                      Colors.amber),
                ],
              )
            ],
          ),

          // TAG PRIORITY
          trailing: _buildPriorityTag(task.priority),
        ),
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

  Widget _buildSmallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10)),
    );
  }

  Widget _buildPriorityTag(String priority) {
    Color color;
    switch (priority) {
      case 'High':
        color = Colors.red;
        break;
      case 'Medium':
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
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(priority,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
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
