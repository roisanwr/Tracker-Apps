/// Model untuk Data Latihan dari Library
class ExerciseModel {
  final String id;
  final String name;
  final String targetMuscle;
  final String scaleType; // strength, endurance, etc.
  final String unit; // reps, seconds, meters

  ExerciseModel({
    required this.id,
    required this.name,
    required this.targetMuscle,
    required this.scaleType,
    required this.unit,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      targetMuscle: json['target_muscle'] ?? 'General',
      scaleType: json['scale_type'] ?? 'strength',
      unit: json['measurement_unit'] ?? 'reps',
    );
  }
}

/// Model untuk Satu Set Latihan (Repetisi, Berat, Status)
class WorkoutSetModel {
  String? id; // Null jika belum disimpan ke DB
  int setNumber;
  String tier; // D, C, B, A, S, SS
  int targetValue;
  int? completedValue;
  double weightKg;
  bool isCompleted;

  WorkoutSetModel({
    this.id,
    required this.setNumber,
    required this.tier,
    required this.targetValue,
    this.completedValue,
    this.weightKg = 0,
    this.isCompleted = false,
  });

  // Konversi ke JSON untuk dikirim ke Supabase
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'set_number': setNumber,
      'tier': tier,
      'target_value': targetValue,
      'completed_value': completedValue,
      'weight_kg': weightKg,
      'is_completed': isCompleted,
    };
  }

  factory WorkoutSetModel.fromJson(Map<String, dynamic> json) {
    return WorkoutSetModel(
      id: json['id']?.toString(),
      setNumber: json['set_number'] ?? 1,
      tier: json['tier'] ?? 'D',
      targetValue: json['target_value'] ?? 0,
      completedValue: json['completed_value'],
      weightKg: (json['weight_kg'] ?? 0).toDouble(),
      isCompleted: json['is_completed'] ?? false,
    );
  }
}

/// Model Helper untuk Halaman Active Workout
/// Menampung Exercise + List Sets yang sedang dikerjakan
class ActiveExerciseModel {
  final ExerciseModel exercise;
  List<WorkoutSetModel> sets;
  String?
      workoutExerciseId; // ID relasi di tabel workout_exercises (Active Session)

  ActiveExerciseModel({
    required this.exercise,
    this.sets = const [],
    this.workoutExerciseId,
  });
}
