import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/workout/data/workout_models.dart';
import 'package:workout_tracker/features/workout/data/workout_repository.dart';
// Kita gak butuh ActiveWorkoutPage lagi karena pakai pop-up
// import 'package:workout_tracker/features/workout/presentation/active_workout_page.dart';

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

  // State Lokal buat nyimpen progress sementara (sebelum dikirim ke DB beneran kalau mau kompleks)
  // Tapi biar simpel, kita anggap pop-up langsung save ke DB atau update state lokal dulu.
  // Map untuk nyimpen status "Selesai" per latihan
  Map<String, bool> _completedExercises = {};

  bool _isLoading = true;
  bool _isPlannerMode = false;

  @override
  void initState() {
    super.initState();
    _todayName = DateFormat('E').format(DateTime.now());
    _selectedDay = _todayName;
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await _repo.ensureWeeklyTemplates();
    await _loadTemplateForDay(_selectedDay);

    if (_templateExercises.isEmpty) {
      setState(() => _isPlannerMode = true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTemplateForDay(String day) async {
    setState(() => _isLoading = true);
    try {
      final exercises = await _repo.getTemplateExercises(day);
      setState(() {
        _selectedDay = day;
        _templateExercises = exercises;
        // Reset progress harian kalau ganti hari (mockup logic)
        _completedExercises.clear();
      });
    } catch (e) {
      debugPrint("Error load template: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- POP-UP ACTION: INPUT EXERCISE ---
  void _showExerciseInput(ExerciseModel ex) {
    showDialog(
      context: context,
      builder: (context) => _ExerciseInputDialog(
        exercise: ex,
        onFinish: () {
          setState(() {
            _completedExercises[ex.id] = true;
          });
          Navigator.pop(context); // Tutup dialog
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("${ex.name} Completed! +XP gained"),
              backgroundColor: AppTheme.primaryColor));
        },
      ),
    );
  }

  void _openAddExerciseSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E1E1E),
        isScrollControlled: true,
        builder: (ctx) => _ExercisePickerAndCreatorSheet(onSelect: (ex) async {
              await _repo.addExerciseToTemplate(_selectedDay, ex);
              Navigator.pop(ctx);
              _loadTemplateForDay(_selectedDay);
            }));
  }

  String _calculateDifficulty() {
    int count = _templateExercises.length;
    if (count == 0) return "Rest";
    if (count <= 3) return "Light";
    if (count <= 5) return "Medium";
    if (count <= 8) return "Hard";
    return "Extreme";
  }

  int _calculatePotentialXP() {
    return _templateExercises.length * 50;
  }

  @override
  Widget build(BuildContext context) {
    // Kita pakai Stack biar tetep bisa numpang di Scaffold Home
    return Stack(
      children: [
        _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : _isPlannerMode
                ? _buildPlannerView()
                : _buildMissionBriefingView(),
        if (_isPlannerMode)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _openAddExerciseSheet,
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppTheme.primaryColor),
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add, color: AppTheme.primaryColor),
            ),
          )
      ],
    );
  }

  // --- VIEW 1: MISSION LIST (Actionable) ---
  Widget _buildMissionBriefingView() {
    int completedCount = _completedExercises.length;
    int totalCount = _templateExercises.length;
    double progress = totalCount == 0 ? 0 : completedCount / totalCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nama Hari & XP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("MISSION STATUS",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(_selectedDay.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Courier')),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.bolt,
                      color: AppTheme.primaryColor, size: 16),
                  Text(" +${_calculatePotentialXP()} XP",
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar,
                        color: Colors.grey, size: 20),
                    onPressed: () => setState(() => _isPlannerMode = true),
                    tooltip: "Edit Schedule",
                  )
                ],
              )
            ],
          ),

          const SizedBox(height: 20),

          // Progress Bar Besar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF1E1E1E),
              color: AppTheme.primaryColor,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text("$completedCount / $totalCount OBJECTIVES CLEARED",
              style: const TextStyle(
                  color: Colors.grey, fontSize: 10, letterSpacing: 1)),

          const SizedBox(height: 20),

          // LIST EXERCISE (Klik untuk Input)
          Expanded(
            child: ListView.separated(
              itemCount: _templateExercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final ex = _templateExercises[i];
                final isDone = _completedExercises[ex.id] ?? false;

                return InkWell(
                  onTap: () =>
                      _showExerciseInput(ex), // KLIK DISINI MUNCUL POPUP
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                        color: isDone
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : const Color(0xFF151A21),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                isDone ? AppTheme.primaryColor : Colors.white10,
                            width: isDone ? 1.5 : 1),
                        boxShadow: isDone
                            ? [
                                BoxShadow(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.2),
                                    blurRadius: 8)
                              ]
                            : []),
                    child: Row(
                      children: [
                        // Icon Status (Kiri)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color:
                                  isDone ? AppTheme.primaryColor : Colors.black,
                              shape: BoxShape.circle),
                          child: Icon(
                            isDone ? Icons.check : Icons.fitness_center,
                            color: isDone ? Colors.black : Colors.grey,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Detail Latihan
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ex.name,
                                  style: TextStyle(
                                      color: isDone
                                          ? AppTheme.primaryColor
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: AppTheme.primaryColor)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _TagBadge(text: ex.targetMuscle),
                                  const SizedBox(width: 8),
                                  _TagBadge(
                                      text: ex.scaleType,
                                      color: AppTheme.secondaryColor),
                                ],
                              )
                            ],
                          ),
                        ),

                        // Panah Indikator
                        if (!isDone)
                          const Icon(Icons.arrow_forward_ios,
                              color: Colors.grey, size: 12)
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- VIEW 2: PLANNER (Sama kayak sebelumnya) ---
  Widget _buildPlannerView() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("DATABASE",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold)),
                  const Text("Weekly Plan",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => setState(() => _isPlannerMode = false),
              )
            ],
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final isSelected = day == _selectedDay;
              final isToday = day == _todayName;

              return GestureDetector(
                onTap: () => _loadTemplateForDay(day),
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !isSelected
                          ? Border.all(color: AppTheme.primaryColor, width: 2)
                          : null),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(day,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : Colors.grey)),
                      if (isToday || isSelected) ...[
                        const SizedBox(height: 4),
                        Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.black
                                    : AppTheme.primaryColor,
                                shape: BoxShape.circle))
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _templateExercises.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _templateExercises.length,
                  itemBuilder: (context, index) {
                    final ex = _templateExercises[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(ex.name,
                            style: const TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
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
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 48, color: Colors.grey[800]),
          const SizedBox(height: 16),
          const Text("No Plan",
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _TagBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _TagBadge({required this.text, this.color = Colors.grey});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.5), width: 0.5)),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }
}

// --- WIDGET PENTING: POP-UP INPUT SET ---
class _ExerciseInputDialog extends StatefulWidget {
  final ExerciseModel exercise;
  final VoidCallback onFinish;

  const _ExerciseInputDialog({required this.exercise, required this.onFinish});

  @override
  State<_ExerciseInputDialog> createState() => _ExerciseInputDialogState();
}

class _ExerciseInputDialogState extends State<_ExerciseInputDialog> {
  // Mockup Data Set (Nanti bisa diambil dari DB history)
  List<Map<String, dynamic>> sets = [
    {'kg': 0, 'reps': 10, 'done': false},
    {'kg': 0, 'reps': 10, 'done': false},
    {'kg': 0, 'reps': 10, 'done': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Dialog
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.exercise.name.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.grey),
                )
              ],
            ),
            const Divider(color: Colors.white10, height: 30),

            // List Set Input
            ...List.generate(sets.length, (index) {
              final set = sets[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text("SET ${index + 1}",
                        style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontFamily: 'Courier')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4)),
                        alignment: Alignment.center,
                        child: Text("${set['kg']} KG",
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4)),
                        alignment: Alignment.center,
                        child: Text("${set['reps']} REPS",
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => set['done'] = !set['done']),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: set['done']
                                ? AppTheme.primaryColor
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(4)),
                        child: Icon(Icons.check,
                            size: 16,
                            color: set['done'] ? Colors.black : Colors.white),
                      ),
                    )
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            // Tombol Tambah Set (Visual)
            InkWell(
              onTap: () => setState(
                  () => sets.add({'kg': 0, 'reps': 10, 'done': false})),
              child: const Text("+ Add Set",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),

            const SizedBox(height: 24),

            // Tombol Finish Exercise
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onFinish, // Panggil Callback Finish
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("FINISH EXERCISE",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ... Picker Class (Tetap sama, copy dari sebelumnya ya biar lengkap)
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
      decoration: const BoxDecoration(
          color: Color(0xFF151A21),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2)),
              margin: const EdgeInsets.only(bottom: 20)),
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [Tab(text: "Library"), Tab(text: "Custom")],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
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
