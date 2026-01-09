class TaskModel {
  final String id;
  final String title;
  final String category;
  final String priority; // 'Low', 'Medium', 'High'
  final String frequency; // 'Daily', 'Weekly', 'OneTime'

  // Target dan unit
  final int targetValue;
  final String unit;

  // Status
  final int currentValue;
  final bool isCompleted;

  // Timestamps
  final DateTime? lastCompletedAt;
  final DateTime? createdAt;

  TaskModel({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.frequency,
    required this.targetValue,
    required this.unit,
    required this.currentValue,
    required this.isCompleted,
    required this.lastCompletedAt,
    required this.createdAt,
  });

  // Mengubah data JSON dari Supabase menjadi Object Dart
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseMaybeDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return TaskModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'No Title',
      category: json['category'] ?? 'General',
      priority: json['priority'] ?? 'Medium',
      frequency: json['frequency'] ?? 'Daily',
      targetValue: (json['target_value'] is int)
          ? json['target_value'] as int
          : int.tryParse(json['target_value']?.toString() ?? '') ?? 1,
      unit: json['unit'] ?? 'Checklist',
      currentValue: (json['current_value'] is int)
          ? json['current_value'] as int
          : int.tryParse(json['current_value']?.toString() ?? '') ?? 0,
      isCompleted: json['is_completed'] ?? false,
      lastCompletedAt: parseMaybeDate(json['last_completed_at']),
      createdAt: parseMaybeDate(json['created_at']),
    );
  }

  // Mengubah Object Dart menjadi JSON untuk dikirim ke Supabase
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'category': category,
      'priority': priority,
      'frequency': frequency,
      'target_value': targetValue,
      'unit': unit,
      'current_value': currentValue,
      'is_completed': isCompleted,
      'last_completed_at': lastCompletedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // Simple reward calculation based on priority
  int get xpReward {
    switch (priority) {
      case 'High':
        return 50;
      case 'Medium':
        return 20;
      default:
        return 10;
    }
  }

  int get goldReward {
    switch (priority) {
      case 'High':
        return 20;
      case 'Medium':
        return 10;
      default:
        return 5;
    }
  }
}
