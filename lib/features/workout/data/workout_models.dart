// 1. Model untuk Library Latihan (Daftar Gerakan)
class ExerciseModel {
  final String id;
  final String name;
  final String targetMuscle;
  final String scaleType; // 'strength', 'endurance', dll
  final String unit; // 'reps', 'seconds', 'meters'

  ExerciseModel({
    required this.id,
    required this.name,
    required this.targetMuscle,
    required this.scaleType,
    required this.unit,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      targetMuscle: json['target_muscle'] ?? 'General',
      scaleType: json['scale_type'] ?? 'strength',
      unit: json['measurement_unit'] ?? 'reps',
    );
  }
}

// 2. Model untuk Set (Repetisi/Angkatan)
class WorkoutSetModel {
  String? id;
  int setNumber;
  String tier; // 'D', 'C', 'B', 'A', 'S', 'SS'
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
      id: json['id'],
      setNumber: json['set_number'] ?? 1,
      tier: json['tier'] ?? 'D',
      targetValue: json['target_value'] ?? 0,
      completedValue: json['completed_value'],
      weightKg: (json['weight_kg'] ?? 0).toDouble(),
      isCompleted: json['is_completed'] ?? false,
    );
  }
}

// 3. Model untuk Exercise yang SEDANG dilakukan (Active)
class ActiveExerciseModel {
  String? id; // ID di tabel workout_exercises
  final ExerciseModel exercise;
  List<WorkoutSetModel> sets;
  String? notes;

  ActiveExerciseModel({
    this.id,
    required this.exercise,
    this.sets = const [],
    this.notes,
  });
}
