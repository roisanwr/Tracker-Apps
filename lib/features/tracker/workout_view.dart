import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:workout_tracker/core/theme/app_theme.dart';
import 'package:workout_tracker/features/tracker/active_workout_page.dart';

class WorkoutView extends StatefulWidget {
  const WorkoutView({super.key});

  @override
  State<WorkoutView> createState() => _WorkoutViewState();
}

// 🛠️ FIX: Hapus SingleTickerProviderStateMixin karena tidak ada TabController di sini
class _WorkoutViewState extends State<WorkoutView> {
  final String _userId = Supabase.instance.client.auth.currentUser!.id;
  late String _todayName;

  @override
  void initState() {
    super.initState();
    _todayName = DateFormat('E').format(DateTime.now());
    _ensureWeeklyTemplatesExist();
  }

  // Cek database, pastikan slot template ada
  Future<void> _ensureWeeklyTemplatesExist() async {
    try {
      final templates = await Supabase.instance.client
          .from('workouts')
          .select()
          .eq('user_id', _userId)
          .eq('status', 'template');

      final List<String> days = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun'
      ];
      if (templates.length < 7) {
        for (var day in days) {
          bool exists = templates.any((t) => t['notes'] == day);
          if (!exists) {
            await Supabase.instance.client.from('workouts').insert({
              'user_id': _userId,
              'status': 'template',
              'notes': day,
              'started_at': DateTime.now().toIso8601String(),
            });
          }
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Error ensuring templates: $e");
    }
  }

  // 📡 STREAM UPGRADED: Gabungkan Rencana (Template) + Realisasi (Log Hari Ini)
  Stream<List<Map<String, dynamic>>> _getTodayWorkoutStream() {
    return Supabase.instance.client
        .from('workouts')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .map((data) {
          // Cast the incoming list from Supabase to a list of maps
          final items = List<Map<String, dynamic>>.from(data);
          final now = DateTime.now();
          final todayStr = DateFormat('yyyy-MM-dd').format(now);

          // 1. Ambil Template Hari Ini
          final templates = items
              .where(
                  (w) => w['status'] == 'template' && w['notes'] == _todayName)
              .toList();

          // 2. Ambil Workout Selesai Hari Ini
          final completed = items.where((w) {
            if (w['status'] != 'completed') return false;
            if (w['started_at'] == null) return false;
            final date = DateTime.parse(w['started_at']).toLocal();
            return DateFormat('yyyy-MM-dd').format(date) == todayStr;
          }).toList();

          return {
            'template': templates.isNotEmpty ? templates.first : null,
            'completed': completed
          };
        })
        .asyncMap((payload) async {
          // payload comes from the previous map: cast fields appropriately
          final template = payload['temp late'] as Map<String, dynamic>?;
          final completedWorkouts = payload['completed'] as List<dynamic>;

          if (template == null) return <Map<String, dynamic>>[];

          final templateId = template['id'];

          // 3. Ambil Plan Latihan
          final templateExercises = await Supabase.instance.client
              .from('workout_exercises')
              .select('*, exercise_library(*), sets(*)')
              .eq('workout_id', templateId);

          // 4. Ambil Realisasi Latihan (Jika ada sesi selesai hari ini)
          List<dynamic> completedExercises = [];
          if (completedWorkouts.isNotEmpty) {
            final workoutIds = completedWorkouts.map((w) => w['id']).toList();
            // Gunakan .filter('col', 'in', list)
            completedExercises = await Supabase.instance.client
                .from('workout_exercises')
                .select('*, sets(*)')
                .filter('workout_id', 'in', workoutIds);
          }

          // 5. GABUNGKAN DATA (Plan + Realisasi)
          return List<Map<String, dynamic>>.from(
              templateExercises.map((planItem) {
            final exerciseId = planItem['exercise_id'];

            // Cari record latihan yang sama di daftar 'completed'
            final matches = completedExercises
                .where((c) => c['exercise_id'] == exerciseId)
                .toList();

            int totalCompletedReps = 0;
            bool isDone = matches.isNotEmpty;

            if (isDone) {
              for (var m in matches) {
                final sets = m['sets'] as List;
                for (var s in sets) {
                  if (s['is_completed'] == true) {
                    totalCompletedReps += (s['completed_value'] as int? ?? 0);
                  }
                }
              }
            }

            // Masukkan data realisasi ke dalam item
            final mutableItem = Map<String, dynamic>.from(planItem);
            mutableItem['realization'] = {
              'is_done': isDone,
              'total_completed': totalCompletedReps
            };

            return mutableItem;
          }));
        });
  }

  void _openWeeklyPlanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const WeeklyPlannerPage()),
    );
  }

  // ⚡ SMART START SESSION (AUTO-SPLIT LOGIC) 🧠
  Future<void> _startSession(
      List<Map<String, dynamic>> scheduledExercises) async {
    final List<Map<String, dynamic>> prefilledData =
        scheduledExercises.map((e) {
      // 🛠️ FIX: Pastikan e diperlakukan sebagai Map
      final itemMap = e;
      final exerciseLib = itemMap['exercise_library'];
      final sets = itemMap['sets'] as List;

      String tier = sets.isNotEmpty ? sets.first['tier'] : 'D';
      int totalTarget = sets.isNotEmpty ? sets.first['target_value'] : 0;

      List<Map<String, dynamic>> generatedSets = [];

      // Jika target besar (> 20) dan tipenya Reps (bukan detik/meter), pecah jadi 3 set
      bool shouldSplit =
          totalTarget > 20 && exerciseLib['measurement_unit'] == 'reps';

      if (shouldSplit) {
        int repsPerSet = (totalTarget / 3).ceil();
        generatedSets.add({
          'reps': repsPerSet.toString(),
          'weight': '0',
          'tier': tier,
          'is_completed': false
        });
        generatedSets.add({
          'reps': repsPerSet.toString(),
          'weight': '0',
          'tier': tier,
          'is_completed': false
        });
        generatedSets.add({
          'reps': repsPerSet.toString(),
          'weight': '0',
          'tier': tier,
          'is_completed': false
        });
      } else {
        generatedSets.add({
          'reps': totalTarget.toString(),
          'weight': '0',
          'tier': tier,
          'is_completed': false
        });
      }

      return {
        'exercise': exerciseLib,
        'sets': generatedSets,
      };
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ActiveWorkoutPage(initialExercises: prefilledData),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TODAY'S WORKOUT",
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            letterSpacing: 1.5)),
                    Text(_todayName.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  onPressed: _openWeeklyPlanner,
                  icon: const Icon(Icons.calendar_month,
                      color: AppTheme.primaryColor),
                  tooltip: "Edit Weekly Schedule",
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getTodayWorkoutStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor));
                }

                final exercises = snapshot.data ?? [];

                if (exercises.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.snooze, size: 64, color: Colors.grey[800]),
                        const SizedBox(height: 16),
                        const Text("Rest Day or Not Planned?",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text("No exercises scheduled for $_todayName.",
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _openWeeklyPlanner,
                          icon: const Icon(Icons.edit_calendar,
                              color: Colors.black),
                          label: const Text("Plan Schedule"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.black),
                        )
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: exercises.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = exercises[index];
                    final exercise = item['exercise_library'];
                    final sets = item['sets'] as List;
                    final tier = sets.isNotEmpty ? sets.first['tier'] : '?';
                    final target =
                        sets.isNotEmpty ? sets.first['target_value'] : 0;

                    final realization =
                        item['realization'] as Map<String, dynamic>?;
                    final bool isDone = realization?['is_done'] ?? false;
                    final int completedAmount =
                        realization?['total_completed'] ?? 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppTheme.secondaryColor.withOpacity(0.1)
                            : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDone
                                ? AppTheme.secondaryColor.withOpacity(0.5)
                                : Colors.white10),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: isDone
                                  ? AppTheme.secondaryColor
                                  : Colors.black,
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(
                              isDone ? Icons.check : Icons.fitness_center,
                              color: isDone ? Colors.black : Colors.grey,
                              size: 20),
                        ),
                        title: Text(exercise['name'],
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                decoration:
                                    isDone ? TextDecoration.lineThrough : null,
                                decorationColor: AppTheme.secondaryColor)),
                        subtitle: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8, top: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text("Tier $tier",
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10)),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                isDone
                                    ? "Done: $completedAmount / $target ${exercise['measurement_unit']}"
                                    : "Target: $target ${exercise['measurement_unit']}",
                                style: TextStyle(
                                    color: isDone
                                        ? AppTheme.secondaryColor
                                        : Colors.grey,
                                    fontWeight: isDone
                                        ? FontWeight.bold
                                        : FontWeight.normal),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getTodayWorkoutStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _startSession(snapshot.data!),
            backgroundColor: AppTheme.primaryColor,
            icon: const Icon(Icons.play_arrow, color: Colors.black),
            label: const Text("START SESSION",
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          );
        },
      ),
    );
  }
}

// =============================================================================
// 📅 WEEKLY PLANNER PAGE
// =============================================================================

class WeeklyPlannerPage extends StatefulWidget {
  const WeeklyPlannerPage({super.key});

  @override
  State<WeeklyPlannerPage> createState() => _WeeklyPlannerPageState();
}

class _WeeklyPlannerPageState extends State<WeeklyPlannerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final String _userId = Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    int todayIndex = DateTime.now().weekday - 1;
    _tabController =
        TabController(length: 7, vsync: this, initialIndex: todayIndex);
    _ensureWeeklyTemplatesExist();
  }

  Future<void> _ensureWeeklyTemplatesExist() async {
    try {
      final templates = await Supabase.instance.client
          .from('workouts')
          .select()
          .eq('user_id', _userId)
          .eq('status', 'template');

      if (templates.length < 7) {
        for (var day in _days) {
          bool exists = templates.any((t) => t['notes'] == day);
          if (!exists) {
            await Supabase.instance.client.from('workouts').insert({
              'user_id': _userId,
              'status': 'template',
              'notes': day,
              'started_at': DateTime.now().toIso8601String(),
            });
          }
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Init Error: $e"), backgroundColor: Colors.red));
    }
  }

  Stream<List<Map<String, dynamic>>> _getScheduleStream(String day) {
    return Supabase.instance.client
        .from('workouts')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .map((data) => data
            .where((w) => w['status'] == 'template' && w['notes'] == day)
            .toList())
        .asyncMap((workouts) async {
          if (workouts.isEmpty) return [];
          final workoutId = workouts.first['id'];
          final response = await Supabase.instance.client
              .from('workout_exercises')
              .select('*, exercise_library(*), sets(*)')
              .eq('workout_id', workoutId);
          return List<Map<String, dynamic>>.from(response);
        });
  }

  void _showAddDialog(String day) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        builder: (_, controller) => _ScheduleEditorSheet(
          day: day,
          userId: _userId,
          scrollController: controller,
          onSave: () => setState(() {}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("WEEKLY PLANNER",
            style: TextStyle(
                color: Colors.white, fontSize: 16, letterSpacing: 1.5)),
        leading: const BackButton(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: _days.map((day) => Tab(text: day)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days.map((day) => _buildDayEditor(day)).toList(),
      ),
    );
  }

  Widget _buildDayEditor(String day) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getScheduleStream(day),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));

        final schedule = snapshot.data ?? [];

        return Column(
          children: [
            Expanded(
              child: schedule.isEmpty
                  ? Center(
                      child: Text("No exercises for $day",
                          style: const TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: schedule.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = schedule[index];
                        final exercise = item['exercise_library'];
                        final sets = item['sets'] as List;
                        final tier = sets.isNotEmpty ? sets.first['tier'] : '?';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          tileColor: const Color(0xFF1E1E1E),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          title: Text(exercise['name'],
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text("Tier $tier",
                              style: const TextStyle(color: Colors.grey)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () async {
                              await Supabase.instance.client
                                  .from('workout_exercises')
                                  .delete()
                                  .eq('id', item['id']);
                              setState(() {});
                            },
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddDialog(day),
                  icon: const Icon(Icons.add, color: AppTheme.primaryColor),
                  label: const Text("ADD EXERCISE",
                      style: TextStyle(color: AppTheme.primaryColor)),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// ⚡ EDITOR SHEET UPGRADE: HYBRID INPUT (LIBRARY vs CUSTOM)
// -----------------------------------------------------------------------------
class _ScheduleEditorSheet extends StatefulWidget {
  final String day;
  final String userId;
  final ScrollController scrollController;
  final VoidCallback onSave;

  const _ScheduleEditorSheet(
      {required this.day,
      required this.userId,
      required this.scrollController,
      required this.onSave});

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  // Mode: 'library' atau 'custom'
  String _mode = 'library';

  // Controller untuk Custom Input
  final _customNameController = TextEditingController();
  String _customMuscle = 'Chest';
  String _customType = 'strength';

  // 🛠️ FIX: Dispose controller biar gak memory leak
  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  void _addExerciseToSchedule(
      Map<String, dynamic> exercise, String tier) async {
    try {
      final templateQuery = await Supabase.instance.client
          .from('workouts')
          .select()
          .eq('user_id', widget.userId)
          .eq('status', 'template')
          .eq('notes', widget.day);

      if (templateQuery.isEmpty) {
        throw "Template for ${widget.day} not found! Please refresh.";
      }

      final workoutId = templateQuery.first['id'];

      final scaleRes = await Supabase.instance.client
          .from('difficulty_scales')
          .select()
          .eq('scale_type', exercise['scale_type'])
          .eq('tier', tier)
          .maybeSingle();

      int targetValue = scaleRes != null ? scaleRes['target_value'] : 10;

      final weRes = await Supabase.instance.client
          .from('workout_exercises')
          .insert({
            'workout_id': workoutId,
            'exercise_id': exercise['id'],
          })
          .select()
          .single();

      await Supabase.instance.client.from('sets').insert({
        'workout_exercise_id': weRes['id'],
        'set_number': 0,
        'tier': tier,
        'target_value': targetValue,
        'completed_value': 0,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Added ${exercise['name']} to ${widget.day}"),
            backgroundColor: AppTheme.secondaryColor));
        widget.onSave();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _saveCustomExercise() async {
    if (_customNameController.text.isEmpty) return;

    try {
      final res = await Supabase.instance.client
          .from('exercise_library')
          .insert({
            'name': _customNameController.text,
            'target_muscle': _customMuscle,
            'scale_type': _customType,
            'measurement_unit': _customType == 'cardio_run'
                ? 'meters'
                : (_customType == 'static_hold' ? 'seconds' : 'reps'),
            'created_by': widget.userId,
          })
          .select()
          .single();

      if (mounted) {
        _showTierPicker(res);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error creating exercise: $e"),
            backgroundColor: Colors.red));
    }
  }

  void _showTierPicker(Map<String, dynamic> exercise) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("Select Tier for ${exercise['name']}",
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['D', 'C', 'B', 'A', 'S', 'SS'].map((tier) {
            return ListTile(
              title: Text("Tier $tier",
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _addExerciseToSchedule(exercise, tier);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeButton("Library", "library"),
                const SizedBox(width: 12),
                _buildModeButton("Custom +", "custom"),
              ],
            ),
          ),
          Expanded(
            child:
                _mode == 'library' ? _buildLibraryList() : _buildCustomForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, String value) {
    bool isSelected = _mode == value;
    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryColor),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLibraryList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('exercise_library')
          .stream(primaryKey: ['id']).order('name', ascending: true),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor));

        final exercises = snapshot.data!;
        return ListView.separated(
          controller: widget.scrollController,
          itemCount: exercises.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white10),
          itemBuilder: (context, index) {
            final ex = exercises[index];
            return ListTile(
              title:
                  Text(ex['name'], style: const TextStyle(color: Colors.white)),
              subtitle: Text("${ex['target_muscle']} • ${ex['scale_type']}",
                  style: const TextStyle(color: Colors.grey)),
              onTap: () => _showTierPicker(ex),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomForm() {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Create New Exercise",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _customNameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Exercise Name",
              labelStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _customMuscle,
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                labelText: "Target Muscle",
                labelStyle: TextStyle(color: Colors.grey)),
            items: [
              'Chest',
              'Back',
              'Legs',
              'Arms',
              'Shoulders',
              'Core',
              'Full Body',
              'Cardio'
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => _customMuscle = val!),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _customType,
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
                labelText: "Type (Scale)",
                labelStyle: TextStyle(color: Colors.grey)),
            items: [
              DropdownMenuItem(
                  value: 'strength', child: Text("Strength (Reps)")),
              DropdownMenuItem(
                  value: 'endurance', child: Text("Endurance (High Reps)")),
              DropdownMenuItem(value: 'power', child: Text("Power (Low Reps)")),
              DropdownMenuItem(
                  value: 'static_hold', child: Text("Static (Seconds)")),
              DropdownMenuItem(
                  value: 'cardio_run', child: Text("Cardio (Distance)")),
            ].toList(),
            onChanged: (val) => setState(() => _customType = val!),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveCustomExercise,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.black,
              ),
              child: const Text("CREATE & ADD TO SCHEDULE",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Note: This will add the exercise to the library permanently.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }
}
