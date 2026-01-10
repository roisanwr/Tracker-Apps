import 'package:flutter/material.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/task/data/task_model.dart';
import 'package:workout_tracker/features/task/data/task_repository.dart';
import 'package:workout_tracker/features/task/presentation/widgets/task_form_dialog.dart';

class TaskView extends StatefulWidget {
  const TaskView({super.key});

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  final TaskRepository _repository = TaskRepository();

  // State UI
  bool _isGenerating = false;
  final Set<String> _processingTaskIds = {}; // Untuk Optimistic UI
  String _selectedFrequency = 'All';
  bool _hideCompleted = false;

  @override
  void initState() {
    super.initState();
    // Auto-check reset saat dibuka (Logic ada di Repository)
    _handleRefresh();
  }

  // Smart Reset manual trigger
  Future<void> _handleRefresh() async {
    final count = await _repository.refreshDailyTasks();
    if (count > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("New Day Started! 🌅 Reset $count tasks."),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    }
  }

  // Generate Tasks
  Future<void> _generateDailyTasks() async {
    setState(() => _isGenerating = true);
    try {
      String targetFreq =
          _selectedFrequency == 'All' ? 'Daily' : _selectedFrequency;
      int count = await _repository.generateTasksFromLibrary(targetFreq);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Generated $count $targetFreq missions!"),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // Toggle Task (Optimistic UI)
  Future<void> _toggleTask(TaskModel task, bool? value) async {
    if (value == null || _processingTaskIds.contains(task.id)) return;

    setState(() => _processingTaskIds.add(task.id));

    try {
      // Panggil Repo untuk update DB & Log
      final reward = await _repository.toggleTask(task, value);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? "Completed! +${reward['xp']} XP"
                  : "Undone. ${reward['xp']} XP",
            ),
            backgroundColor: value ? AppTheme.secondaryColor : Colors.grey,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _processingTaskIds.remove(task.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // --- HEADER & FILTER ---
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Daily'),
                const SizedBox(width: 8),
                _buildFilterChip('Weekly'),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _hideCompleted ? Icons.visibility_off : Icons.visibility,
                    color: _hideCompleted ? Colors.redAccent : Colors.grey,
                  ),
                  tooltip: _hideCompleted ? 'Show Completed' : 'Hide Completed',
                  onPressed: () =>
                      setState(() => _hideCompleted = !_hideCompleted),
                ),
              ],
            ),
          ),

          // --- LIST TASK ---
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppTheme.primaryColor,
              backgroundColor: const Color(0xFF1E1E1E),
              child: StreamBuilder<List<TaskModel>>(
                stream: _repository.getTasksStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryColor));
                  }

                  // Filter Client Side (karena Supabase Stream limitasi filter dinamis)
                  var tasks = snapshot.data ?? [];
                  if (_selectedFrequency != 'All') {
                    tasks = tasks
                        .where((t) => t.frequency == _selectedFrequency)
                        .toList();
                  }
                  if (_hideCompleted) {
                    tasks = tasks.where((t) => !t.isCompleted).toList();
                  }

                  // Empty State
                  if (tasks.isEmpty) {
                    return ListView(children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: _buildEmptyState(),
                      )
                    ]);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildTaskCard(tasks[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),

      // --- FAB (ADD) ---
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
            context: context,
            builder: (ctx) =>
                TaskFormDialog(initialFrequency: _selectedFrequency)),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  // --- WIDGETS KECIL (Bisa dipisah lagi ke file task_card.dart kalau mau ultra-clean) ---

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFrequency == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool value) {
        if (value) setState(() => _selectedFrequency = label);
      },
      backgroundColor: const Color(0xFF1E1E1E),
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      checkmarkColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[800]!),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined,
              size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(
            _hideCompleted
                ? "All active $_selectedFrequency missions cleared! 🎉"
                : "No $_selectedFrequency Missions Active",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _isGenerating
              ? const CircularProgressIndicator(color: AppTheme.primaryColor)
              : ElevatedButton.icon(
                  onPressed: _generateDailyTasks,
                  icon: const Icon(Icons.auto_awesome, color: Colors.black),
                  label: Text(
                      "Generate ${_selectedFrequency == 'All' ? 'Daily' : _selectedFrequency} Tasks"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black),
                ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final bool isProcessing = _processingTaskIds.contains(task.id);

    // Warna Badge
    Color badgeColor = Colors.orange;
    if (task.priority == 'High') badgeColor = Colors.redAccent;
    if (task.priority == 'Low') badgeColor = Colors.green;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: task.isCompleted ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: task.isCompleted ? Colors.transparent : Colors.white10),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onLongPress: () {
            if (task.isCompleted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Uncheck task to edit/delete"),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 1)));
            } else {
              _showTaskOptions(task);
            }
          },
          leading: isProcessing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryColor))
              : Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: task.isCompleted,
                    activeColor: AppTheme.secondaryColor,
                    checkColor: Colors.black,
                    side: BorderSide(color: Colors.grey[600]!, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => _toggleTask(task, val),
                  ),
                ),
          title: Text(
            task.title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              decorationColor: AppTheme.primaryColor,
              decorationThickness: 2,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Row(
              children: [
                _buildBadge(task.priority.toUpperCase(), badgeColor),
                const SizedBox(width: 8),
                if (_selectedFrequency == 'All') ...[
                  _buildBadge(task.frequency, Colors.blueAccent),
                  const SizedBox(width: 8),
                ],
                Text("${task.targetValue} ${task.unit}",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          trailing: _getCategoryIcon(task.category),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _getCategoryIcon(String category) {
    IconData icon = Icons.extension;
    Color color = Colors.grey;
    switch (category) {
      case 'Intellect':
        icon = Icons.psychology;
        color = Colors.blue;
        break;
      case 'Vitality':
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case 'Wealth':
        icon = Icons.attach_money;
        color = Colors.green;
        break;
      case 'Charisma':
        icon = Icons.record_voice_over;
        color = Colors.purple;
        break;
    }
    return Icon(icon, color: color.withOpacity(0.4));
  }

  void _showTaskOptions(TaskModel task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blueAccent),
            title: const Text('Edit Mission',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              showDialog(
                  context: context,
                  builder: (_) => TaskFormDialog(
                      taskToEdit: task, initialFrequency: _selectedFrequency));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.redAccent),
            title: const Text('Delete Mission',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              Navigator.pop(ctx);
              await _repository.deleteTask(task.id);
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Mission deleted'),
                    backgroundColor: Colors.grey));
            },
          ),
        ],
      ),
    );
  }
}
