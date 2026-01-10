import 'package:flutter/material.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/task/data/task_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers & State Form
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _targetController =
      TextEditingController(text: '1');
  final TextEditingController _unitController =
      TextEditingController(text: 'Kali');

  String _selectedCategory = 'Vitality';
  String _selectedPriority = 'Medium';
  bool _isLoading = false;

  // Pilihan Kategori RPG
  final List<String> _categories = [
    'Strength',
    'Vitality',
    'Intellect',
    'Wealth',
    'Charisma',
    'Discipline'
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High'];

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // Persiapkan Data untuk dikirim ke Supabase
      // Kita pakai Map manual karena TaskModel biasanya untuk read (fromJson)
      // Tapi kalau mau rapi bisa bikin method toInsertJson di model.
      final newTaskData = {
        'user_id': userId,
        'title': _titleController.text.trim(),
        'category': _selectedCategory,
        'priority': _selectedPriority,
        'frequency': 'Daily', // Default Daily dulu sesuai scope
        'target_value': int.parse(_targetController.text),
        'unit': _unitController.text.trim(),
        'current_value': 0,
        'is_completed': false,
      };

      await Supabase.instance.client.from('tasks').insert(newTaskData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Misi baru berhasil ditambahkan! 🚀"),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Kembali ke halaman list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("New Mission",
            style: TextStyle(fontFamily: 'monospace')),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. JUDUL MISI
            _buildLabel("Mission Title"),
            TextFormField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Ex: Push Up 50x"),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Judul wajib diisi' : null,
            ),
            const SizedBox(height: 20),

            // 2. KATEGORI (Chips)
            _buildLabel("Attribute (Category)"),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: Colors.grey[900],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) => setState(() => _selectedCategory = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 3. PRIORITAS (Dropdown/Segmented)
            _buildLabel("Difficulty (Priority)"),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: _priorities.map((prio) {
                  final isSelected = _selectedPriority == prio;
                  Color color;
                  if (prio == 'High')
                    color = Colors.red;
                  else if (prio == 'Medium')
                    color = Colors.amber;
                  else
                    color = Colors.green;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPriority = prio),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.2) : null,
                          border: isSelected ? Border.all(color: color) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(prio,
                                style: TextStyle(
                                    color: isSelected ? color : Colors.grey,
                                    fontWeight: FontWeight.bold)),
                            if (isSelected) // Reward Info Kecil
                              Text(
                                  prio == 'High'
                                      ? "+50 XP"
                                      : (prio == 'Medium'
                                          ? "+20 XP"
                                          : "+10 XP"),
                                  style: TextStyle(color: color, fontSize: 10))
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // 4. TARGET & UNIT (Row)
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Target"),
                      TextFormField(
                        controller: _targetController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration("10"),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Wajib' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Unit"),
                      TextFormField(
                        controller: _unitController,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            _inputDecoration("Ex: Reps, Minutes, Pages"),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Wajib' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // TOMBOL SAVE
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submitTask,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text("CREATE MISSION",
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child:
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[700]),
      filled: true,
      fillColor: Colors.grey[900],
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
