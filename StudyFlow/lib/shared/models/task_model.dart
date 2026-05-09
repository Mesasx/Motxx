class TaskModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? dueTime;
  final String? category;
  final bool completed;
  final String? routineId;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.dueDate,
    this.dueTime,
    this.category,
    this.completed = false,
    this.routineId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.fromMap(Map<String, dynamic> m) {
    return TaskModel(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      title: m['title'] as String,
      description: m['description'] as String?,
      dueDate: m['due_date'] != null
          ? DateTime.parse(m['due_date'] as String)
          : null,
      dueTime: m['due_time'] as String?,
      category: m['category'] as String?,
      completed: (m['completed'] ?? false) as bool,
      routineId: m['routine_id'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'due_date': dueDate?.toIso8601String().substring(0, 10),
      'due_time': dueTime,
      'category': category,
      'completed': completed,
      'routine_id': routineId,
    };
  }

  TaskModel copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    String? dueTime,
    String? category,
    bool? completed,
    String? routineId,
  }) {
    return TaskModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      category: category ?? this.category,
      completed: completed ?? this.completed,
      routineId: routineId ?? this.routineId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
