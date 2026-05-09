enum RoutineType { exams, work, sport, daily }

extension RoutineTypeX on RoutineType {
  String get value {
    switch (this) {
      case RoutineType.exams:
        return 'exams';
      case RoutineType.work:
        return 'work';
      case RoutineType.sport:
        return 'sport';
      case RoutineType.daily:
        return 'daily';
    }
  }

  static RoutineType fromString(String s) {
    return RoutineType.values
        .firstWhere((e) => e.value == s, orElse: () => RoutineType.daily);
  }
}

class RoutineModel {
  final String id;
  final String userId;
  final RoutineType type;
  final String name;
  final Map<String, dynamic> config;
  final bool active;
  final DateTime createdAt;

  RoutineModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    required this.config,
    this.active = true,
    required this.createdAt,
  });

  factory RoutineModel.fromMap(Map<String, dynamic> m) {
    return RoutineModel(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      type: RoutineTypeX.fromString(m['type'] as String),
      name: m['name'] as String,
      config: Map<String, dynamic>.from(m['config'] ?? {}),
      active: (m['active'] ?? true) as bool,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'type': type.value,
      'name': name,
      'config': config,
      'active': active,
    };
  }
}

class RoutineItemModel {
  final String id;
  final String routineId;
  final String name;
  final Map<String, dynamic> metadata;
  final DateTime? dueDate;
  final bool completed;

  RoutineItemModel({
    required this.id,
    required this.routineId,
    required this.name,
    required this.metadata,
    this.dueDate,
    this.completed = false,
  });

  factory RoutineItemModel.fromMap(Map<String, dynamic> m) {
    return RoutineItemModel(
      id: m['id'] as String,
      routineId: m['routine_id'] as String,
      name: m['name'] as String,
      metadata: Map<String, dynamic>.from(m['metadata'] ?? {}),
      dueDate: m['due_date'] != null
          ? DateTime.parse(m['due_date'] as String)
          : null,
      completed: (m['completed'] ?? false) as bool,
    );
  }
}
