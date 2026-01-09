class TaskModel {
  final String id;
  final String title;
  final String description;
  final int xpReward;
  final int goldReward;
  final String difficulty; // 'Easy', 'Medium', 'Hard'
  final bool isCompleted;
  final String frequency; // 'Daily', 'Weekly', 'OneTime'

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.xpReward,
    required this.goldReward,
    required this.difficulty,
    required this.isCompleted,
    required this.frequency,
  });

  // Mengubah data JSON dari Supabase menjadi Object Dart
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'No Title',
      description: json['description'] ?? '',
      xpReward: json['xp_reward'] ?? 10,
      goldReward: json['gold_reward'] ?? 5,
      difficulty: json['difficulty'] ?? 'Easy',
      isCompleted: json['is_completed'] ?? false,
      frequency: json['frequency'] ?? 'Daily',
    );
  }

  // Mengubah Object Dart menjadi JSON untuk dikirim ke Supabase
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'xp_reward': xpReward,
      'gold_reward': goldReward,
      'difficulty': difficulty,
      'is_completed': isCompleted,
      'frequency': frequency,
    };
  }
}
