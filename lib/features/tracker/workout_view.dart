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

class _WorkoutViewState extends State<WorkoutView>
    with SingleTickerProviderStateMixin {
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

  Stream<List<Map<String, dynamic>>> _getTodayWorkoutStream() {
    return Supabase.instance.client
        .from('workouts')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .map((data) => data
            .where((w) => w['status'] == 'template' && w['notes'] == _todayName)
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

  void _openWeeklyPlanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const WeeklyPlannerPage()),
    );
  }

  // ⚡ UPDATE: Auto-Fill Target ke Input Realisasi
  Future<void> _startSession(
      List<Map<String, dynamic>> scheduledExercises) async {
    final List<Map<String, dynamic>> prefilledData =
        scheduledExercises.map((e) {
      final exerciseLib = e['exercise_library'];
      final sets = e['sets'] as List;

      // Ambil data Tier dan Target dari jadwal
      String tier = sets.isNotEmpty ? sets.first['tier'] : 'D';
      int target = sets.isNotEmpty ? sets.first['target_value'] : 0;

      return {
        'exercise': exerciseLib,
        'sets': <Map<String, dynamic>>[
          {
            // ⚡ UX MAGIC: Pre-fill kolom Reps dengan Target dari Tier!
            // Jadi user gak perlu ngetik ulang, tinggal centang kalau berhasil.
            'reps': target.toString(),

            // Default berat 0
            'weight': '0',

            'tier': tier,
            'is_completed': false
          }
        ]
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

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.fitness_center,
                              color: Colors.grey, size: 20),
                        ),
                        title: Text(exercise['name'],
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text("Tier $tier • Target: $target",
                            style: const TextStyle(color: Colors.grey)),
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

// ... (WeeklyPlannerPage code remains the same)
// ... (ScheduleEditorSheet code remains the same)
// Pastikan WeeklyPlannerPage dan EditorSheet tetap ada di bawah sini seperti file sebelumnya
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
            child: Text("Add to ${widget.day} Schedule",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('exercise_library')
                  .stream(primaryKey: ['id']).order('name', ascending: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor));

                final exercises = snapshot.data!;
                return ListView.separated(
                  controller: widget.scrollController,
                  itemCount: exercises.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final ex = exercises[index];
                    return ListTile(
                      title: Text(ex['name'],
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                          "${ex['target_muscle']} • ${ex['scale_type']}",
                          style: const TextStyle(color: Colors.grey)),
                      onTap: () => _showTierPicker(ex),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
