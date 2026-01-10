import 'package:flutter/material.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/task/data/task_model.dart';
import 'package:workout_tracker/features/task/data/task_repository.dart';

class TaskFormDialog extends StatefulWidget {
  final TaskModel? taskToEdit;
  final String initialFrequency; // 'All' will become 'Daily'

  const TaskFormDialog(
      {super.key, this.taskToEdit, required this.initialFrequency});

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  late TextEditingController _titleController;
  late TextEditingController _targetController;
  late TextEditingController _unitController;
  late String _selectedCategory;
  late String _selectedPriority;
  late String _selectedFrequency;

  @override
  void initState() {
    super.initState();
    final t = widget.taskToEdit;
    _titleController = TextEditingController(text: t?.title ?? '');
    _targetController =
        TextEditingController(text: t?.targetValue.toString() ?? '1');
    _unitController = TextEditingController(text: t?.unit ?? 'x');
    _selectedCategory = t?.category ?? 'Intellect';
    _selectedPriority = t?.priority ?? 'Medium';
    _selectedFrequency = t != null
        ? t.frequency
        : (widget.initialFrequency == 'All'
            ? 'Daily'
            : widget.initialFrequency);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.taskToEdit != null;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        isEditing ? 'Edit Mission' : 'New Custom Mission',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(_titleController, 'Mission Title'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _buildTextField(_targetController, 'Target',
                        isNumber: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(_unitController, 'Unit')),
              ],
            ),
            const SizedBox(height: 16),
            _buildDropdown(
                'Category',
                _selectedCategory,
                ['Intellect', 'Vitality', 'Wealth', 'Charisma'],
                (val) => setState(() => _selectedCategory = val!)),
            const SizedBox(height: 16),
            _buildDropdown(
                'Frequency',
                _selectedFrequency,
                ['Daily', 'Weekly', 'OneTime'],
                (val) => setState(() => _selectedFrequency = val!)),
            const SizedBox(height: 16),
            _buildDropdown(
                'Priority',
                _selectedPriority,
                ['Low', 'Medium', 'High'],
                (val) => setState(() => _selectedPriority = val!)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          onPressed: _saveTask,
          child: Text(
            isEditing ? 'Save' : 'Create',
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppTheme.primaryColor)),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.grey[900],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
      ),
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _saveTask() async {
    if (_titleController.text.isEmpty) return;

    final data = {
      'title': _titleController.text,
      'category': _selectedCategory,
      'priority': _selectedPriority,
      'frequency': _selectedFrequency,
      'target_value': int.tryParse(_targetController.text) ?? 1,
      'unit': _unitController.text,
    };

    try {
      await TaskRepository().saveTask(data, docId: widget.taskToEdit?.id);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        // Callback opsional bisa ditambahkan disini
      }
    } catch (e) {
      debugPrint("Error saving: $e");
    }
  }
}
