class TaskModel {
  final String id;
  final String userId;
  final String title;
  final String category;
  final String priority; // 'Low', 'Medium', 'High'
  final String frequency; // 'Daily', 'Weekly', 'OneTime'
  final int targetValue;
  final String unit;
  final int currentValue;
  final bool isCompleted;
  final bool isCustom; // ✨ NEW: Field baru biar sinkron sama DB
  final DateTime? lastCompletedAt;
  final DateTime? createdAt;

  TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.priority,
    required this.frequency,
    required this.targetValue,
    required this.unit,
    required this.currentValue,
    required this.isCompleted,
    required this.isCustom, // ✨ Wajib diisi
    this.lastCompletedAt,
    this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title'] ?? 'Untitled',
      category: json['category'] ?? 'General',
      priority: json['priority'] ?? 'Medium',
      frequency: json['frequency'] ?? 'Daily',
      targetValue: json['target_value'] is int
          ? json['target_value']
          : int.tryParse(json['target_value']?.toString() ?? '1') ?? 1,
      unit: json['unit'] ?? 'x',
      currentValue: json['current_value'] is int
          ? json['current_value']
          : int.tryParse(json['current_value']?.toString() ?? '0') ?? 0,
      isCompleted: json['is_completed'] ?? false,
      isCustom: json['is_custom'] ?? false, // ✨ Ambil dari JSON, default false
      lastCompletedAt: json['last_completed_at'] != null
          ? DateTime.parse(json['last_completed_at']).toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'category': category,
      'priority': priority,
      'frequency': frequency,
      'target_value': targetValue,
      'unit': unit,
      'current_value': currentValue,
      'is_completed': isCompleted,
      'is_custom': isCustom, // ✨ Kirim balik ke DB
      'last_completed_at': lastCompletedAt?.toIso8601String(),
    };
  }

  // Helper untuk Sorting Priority
  int get priorityScore {
    switch (priority) {
      case 'High':
        return 3;
      case 'Medium':
        return 2;
      default:
        return 1;
    }
  }
}
