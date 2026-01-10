import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/workout/data/workout_models.dart';
import 'package:workout_tracker/features/workout/data/workout_repository.dart';
import 'package:workout_tracker/features/workout/presentation/active_workout_page.dart';

class WorkoutView extends StatefulWidget {
  const WorkoutView({super.key});

  @override
  State<WorkoutView> createState() => _WorkoutViewState();
}

class _WorkoutViewState extends State<WorkoutView> {
  final WorkoutRepository _repo = WorkoutRepository();

  // State
  late String _todayName;
  String _selectedDay = '';
  List<ExerciseModel> _templateExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _todayName = DateFormat('E').format(DateTime.now());
    _selectedDay = _todayName; // Default pilih hari ini
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await _repo.ensureWeeklyTemplates();
    await _loadTemplateForDay(_selectedDay);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTemplateForDay(String day) async {
    setState(() => _isLoading = true);
    try {
      final exercises = await _repo.getTemplateExercises(day);
      setState(() {
        _selectedDay = day;
        _templateExercises = exercises;
      });
    } catch (e) {
      debugPrint("Error load template: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔥 START ACTION: Pindah ke Halaman Aktif dengan membawa daftar latihan
  void _startWorkout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveWorkoutPage(
          initialExercises: _templateExercises,
          sessionName: "$_selectedDay Workout",
        ),
      ),
    );
  }

  void _openAddExerciseSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        isScrollControlled: true, // Supaya bisa full screen saat ngetik
        builder: (ctx) => _ExercisePickerAndCreatorSheet(onSelect: (ex) async {
              await _repo.addExerciseToTemplate(_selectedDay, ex);
              Navigator.pop(ctx);
              _loadTemplateForDay(_selectedDay); // Refresh list
            }));
  }

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      appBar: AppBar(title: const Text('Training Schedule 📅')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. DAY SELECTOR (Senin - Minggu)
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final day = days[index];
                final isSelected = day == _selectedDay;
                final isToday = day == _todayName;

                return GestureDetector(
                  onTap: () => _loadTemplateForDay(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 60,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: isToday
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 8)
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(day,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    isSelected ? Colors.black : Colors.grey)),
                        if (isToday && !isSelected)
                          const Icon(Icons.circle,
                              size: 6, color: AppTheme.primaryColor)
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(color: Colors.white10),

          // 2. LIST LATIHAN (Template Content)
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primaryColor))
                : _templateExercises.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _templateExercises.length,
                        itemBuilder: (context, index) {
                          final ex = _templateExercises[index];
                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(ex.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  "${ex.targetMuscle} • ${ex.scaleType}",
                                  style: const TextStyle(color: Colors.grey)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.redAccent),
                                onPressed: () async {
                                  await _repo.removeExerciseFromTemplate(
                                      _selectedDay, ex.id);
                                  _loadTemplateForDay(_selectedDay);
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // 3. START BUTTON AREA
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                color: Color(0xFF121212),
                border: Border(top: BorderSide(color: Colors.white10))),
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _startWorkout,
                icon: const Icon(Icons.play_arrow, color: Colors.black),
                label: Text("START $_selectedDay WORKOUT",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ),
        ],
      ),
      // Add Exercise Button (Floating di atas Start Button)
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
            bottom: 70), // Supaya gak ketutup Start Button
        child: FloatingActionButton(
          onPressed: _openAddExerciseSheet,
          backgroundColor: const Color(0xFF1E1E1E),
          child: const Icon(Icons.add, color: AppTheme.primaryColor),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center_outlined,
              size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text("No exercises planned for $_selectedDay.",
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          const Text("Tap '+' to add exercises",
              style: TextStyle(color: AppTheme.primaryColor)),
        ],
      ),
    );
  }
}

// --- WIDGET HELPER: PICKER + CREATOR (TOTALITAS!) ---
class _ExercisePickerAndCreatorSheet extends StatefulWidget {
  final Function(ExerciseModel) onSelect;
  const _ExercisePickerAndCreatorSheet({required this.onSelect});

  @override
  State<_ExercisePickerAndCreatorSheet> createState() =>
      _ExercisePickerAndCreatorSheetState();
}

class _ExercisePickerAndCreatorSheetState
    extends State<_ExercisePickerAndCreatorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameCtrl = TextEditingController();
  String _muscle = 'Chest';
  String _type = 'strength';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [Tab(text: "Library"), Tab(text: "Create Custom")],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: LIBRARY LIST
                FutureBuilder<List<ExerciseModel>>(
                  future: WorkoutRepository().getExerciseLibrary(),
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final list = snapshot.data!;
                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white10),
                      itemBuilder: (ctx, i) {
                        final ex = list[i];
                        return ListTile(
                          title: Text(ex.name,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(ex.targetMuscle,
                              style: const TextStyle(color: Colors.grey)),
                          onTap: () => widget.onSelect(ex),
                        );
                      },
                    );
                  },
                ),
                // TAB 2: CREATE FORM
                SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            labelText: "Exercise Name",
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField(
                        value: _muscle,
                        dropdownColor: const Color(0xFF2C2C2C),
                        items: [
                          'Chest',
                          'Back',
                          'Legs',
                          'Shoulders',
                          'Arms',
                          'Core',
                          'Cardio'
                        ]
                            .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m,
                                    style:
                                        const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (v) => setState(() => _muscle = v!),
                        decoration: const InputDecoration(
                            labelText: "Target Muscle",
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField(
                        value: _type,
                        dropdownColor: const Color(0xFF2C2C2C),
                        items: [
                          DropdownMenuItem(
                              value: 'strength',
                              child: Text("Strength (Reps)")),
                          DropdownMenuItem(
                              value: 'endurance',
                              child: Text("Endurance (High Reps)")),
                          DropdownMenuItem(
                              value: 'static_hold',
                              child: Text("Static (Seconds)")),
                          DropdownMenuItem(
                              value: 'cardio_run',
                              child: Text("Cardio (Meters)")),
                        ]
                            .map((item) => DropdownMenuItem(
                                value: item.value,
                                child: Text((item.child as Text).data!,
                                    style:
                                        const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (v) => setState(() => _type = v!),
                        decoration: const InputDecoration(
                            labelText: "Type", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () async {
                          if (_nameCtrl.text.isEmpty) return;
                          try {
                            // Create & Select immediately
                            final newEx = await WorkoutRepository()
                                .createCustomExercise(
                                    _nameCtrl.text, _type, _muscle);
                            widget.onSelect(newEx);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            minimumSize: const Size(double.infinity, 50)),
                        child: const Text("CREATE & ADD",
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
