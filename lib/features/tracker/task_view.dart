import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class TaskView extends StatefulWidget {
  const TaskView({super.key});

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;
  bool _isGenerating = false;
  final Set<String> _processingTaskIds = {}; // Anti-spam set

  // 📡 STREAM
  Stream<List<Map<String, dynamic>>> _getTasksStream() {
    return Supabase.instance.client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('is_completed', ascending: true)
        .order('priority', ascending: true)
        .map((data) => data.where((task) => task['frequency'] == 'Daily').toList());
  }

  // ===========================================================================
  // 🛠️ CRUD ACTION (CREATE / UPDATE / DELETE)
  // ===========================================================================

  // 1. SHOW FORM DIALOG (Bisa buat ADD atau EDIT)
  void _showTaskForm({Map<String, dynamic>? taskToEdit}) {
    final bool isEditing = taskToEdit != null;
    
    // Controller untuk Form
    final titleController = TextEditingController(text: isEditing ? taskToEdit['title'] : '');
    final targetController = TextEditingController(text: isEditing ? taskToEdit['target_value'].toString() : '1');
    final unitController = TextEditingController(text: isEditing ? taskToEdit['unit'] : 'x');
    
    String selectedCategory = isEditing ? taskToEdit['category'] : 'Intellect';
    String selectedPriority = isEditing ? taskToEdit['priority'] : 'Medium';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(isEditing ? 'Edit Mission' : 'New Custom Mission', 
            style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title Input
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Mission Title',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 16),
              
              // Target & Unit Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Target',
                        labelStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Unit (e.g. min, page)',
                        labelStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dropdowns
              DropdownButtonFormField<String>(
                value: selectedCategory,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.grey)),
                items: ['Intellect', 'Vitality', 'Wealth', 'Charisma']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => selectedCategory = val!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedPriority,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Priority', labelStyle: TextStyle(color: Colors.grey)),
                items: ['Low', 'Medium', 'High']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => selectedPriority = val!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (titleController.text.isEmpty) return;
              
              Navigator.pop(ctx); // Tutup dialog dulu
              
              final taskData = {
                'user_id': _userId,
                'title': titleController.text,
                'category': selectedCategory,
                'priority': selectedPriority,
                'frequency': 'Daily',
                'target_value': int.tryParse(targetController.text) ?? 1,
                'unit': unitController.text,
              };

              try {
                if (isEditing) {
                  // UPDATE EXISTING
                  await Supabase.instance.client
                      .from('tasks')
                      .update(taskData)
                      .eq('id', taskToEdit['id']);
                } else {
                  // CREATE NEW
                  // Default fields for new task
                  taskData['current_value'] = 0;
                  taskData['is_completed'] = false;
                  await Supabase.instance.client.from('tasks').insert(taskData);
                }
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEditing ? 'Mission Updated!' : 'Mission Created!'), backgroundColor: AppTheme.secondaryColor)
                  );
                }
              } catch (e) {
                debugPrint(e.toString());
              }
            },
            child: Text(isEditing ? 'Save' : 'Create', style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // 2. SHOW OPTIONS (DELETE / EDIT) - Dipanggil saat Long Press
  void _showTaskOptions(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blueAccent),
            title: const Text('Edit Mission', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              _showTaskForm(taskToEdit: task); // Buka form edit
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.redAccent),
            title: const Text('Delete Mission', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              Navigator.pop(ctx);
              // Confirm Delete
              await Supabase.instance.client.from('tasks').delete().eq('id', task['id']);
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mission deleted'), backgroundColor: Colors.grey)
                 );
              }
            },
          ),
        ],
      ),
    );
  }

  // 3. GENERATE TASKS (Kode lama)
  Future<void> _generateDailyTasks() async {
    setState(() => _isGenerating = true);
    try {
      final templates = await Supabase.instance.client
          .from('task_library')
          .select()
          .eq('default_frequency', 'Daily');

      if (templates.isEmpty) throw "Library Kosong";

      final List<Map<String, dynamic>> newTasks = [];
      for (var t in templates) {
        newTasks.add({
          'user_id': _userId,
          'title': t['title'],
          'category': t['category'],
          'priority': t['default_priority'],
          'frequency': 'Daily',
          'target_value': t['default_target_value'],
          'unit': t['default_unit'],
          'current_value': 0,
          'is_completed': false,
        });
      }
      await Supabase.instance.client.from('tasks').insert(newTasks);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Generated ${newTasks.length} missions!"), backgroundColor: AppTheme.secondaryColor),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // 4. TOGGLE CHECKLIST (Kode lama dengan anti-spam)
  Future<void> _toggleTask(Map<String, dynamic> task, bool? value) async {
    if (value == null) return;
    final String taskId = task['id'];
    if (_processingTaskIds.contains(taskId)) return;

    setState(() => _processingTaskIds.add(taskId));

    final String title = task['title'];
    final String priority = task['priority'] ?? 'Medium';
    final bool isCompleted = value;

    try {
      await Supabase.instance.client.from('tasks').update({
        'is_completed': isCompleted,
        'current_value': isCompleted ? task['target_value'] : 0, 
        'last_completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
      }).eq('id', taskId); 

      int xpReward = 0;
      int pointsReward = 0;
      switch (priority) {
        case 'High': xpReward = 50; pointsReward = 15; break;
        case 'Medium': xpReward = 30; pointsReward = 10; break;
        case 'Low': xpReward = 10; pointsReward = 5; break;
        default: xpReward = 20; pointsReward = 5;
      }
      if (!isCompleted) {
        xpReward = -xpReward;
        pointsReward = -pointsReward;
      }

      await Supabase.instance.client.from('point_logs').insert({
        'user_id': _userId,
        'xp_change': xpReward,
        'points_change': pointsReward,
        'source_type': 'task',
        'description': isCompleted ? 'Completed: $title' : 'Undo: $title',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCompleted ? "Mission Complete! +$xpReward XP" : "Mission Undone. $xpReward XP"),
            backgroundColor: isCompleted ? AppTheme.secondaryColor : Colors.grey,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _processingTaskIds.remove(taskId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getTasksStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final tasks = snapshot.data!;
          tasks.sort((a, b) {
            if (a['is_completed'] != b['is_completed']) return a['is_completed'] ? 1 : -1;
            final pA = _priorityScore(a['priority']);
            final pB = _priorityScore(b['priority']);
            return pB.compareTo(pA); 
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskCard(task);
            },
          );
        },
      ),
      // ⚡ UPDATED FAB: Memanggil _showTaskForm()
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskForm(), // Buka Dialog Tambah
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  int _priorityScore(String? p) {
    if (p == 'High') return 3;
    if (p == 'Medium') return 2;
    return 1;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          const Text("No Missions Active", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _isGenerating
              ? const CircularProgressIndicator(color: AppTheme.primaryColor)
              : ElevatedButton.icon(
                  onPressed: _generateDailyTasks,
                  icon: const Icon(Icons.auto_awesome, color: Colors.black),
                  label: const Text("Generate Daily Tasks"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final bool isCompleted = task['is_completed'] ?? false;
    final String taskId = task['id'];
    final bool isProcessing = _processingTaskIds.contains(taskId);
    final String priority = task['priority'] ?? 'Medium';
    
    Color badgeColor = Colors.orange;
    if (priority == 'High') badgeColor = Colors.redAccent;
    if (priority == 'Low') badgeColor = Colors.green;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isCompleted ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isCompleted ? Colors.transparent : Colors.white10),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // ⚡ FITUR BARU: Long Press buat Edit/Hapus
          onLongPress: () => _showTaskOptions(task),
          
          leading: isProcessing 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor))
            : Transform.scale(
                scale: 1.2,
                child: Checkbox(
                  value: isCompleted,
                  activeColor: AppTheme.secondaryColor,
                  checkColor: Colors.black,
                  side: BorderSide(color: Colors.grey[600]!, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) => _toggleTask(task, val),
                ),
              ),
          title: Text(
            task['title'] ?? 'Untitled',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              decorationColor: AppTheme.primaryColor,
              decorationThickness: 2,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: badgeColor.withOpacity(0.5)),
                  ),
                  child: Text(priority.toUpperCase(), style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text("${task['target_value']} ${task['unit']}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          trailing: _getCategoryIcon(task['category']),
        ),
      ),
    );
  }

  Widget _getCategoryIcon(String? category) {
    IconData icon = Icons.extension;
    Color color = Colors.grey;
    if (category == 'Intellect') { icon = Icons.psychology; color = Colors.blue; }
    if (category == 'Vitality') { icon = Icons.favorite; color = Colors.red; }
    if (category == 'Wealth') { icon = Icons.attach_money; color = Colors.green; }
    if (category == 'Charisma') { icon = Icons.record_voice_over; color = Colors.purple; }
    return Icon(icon, color: color.withOpacity(0.4));
  }
}