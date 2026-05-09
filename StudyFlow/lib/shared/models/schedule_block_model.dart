class ScheduleBlockModel {
  final String id;
  final String userId;
  final String subject;
  final String? location;
  final String? teacher;
  final String? color;
  final int dayOfWeek; // 1=Mon ... 7=Sun
  final String startTime; // HH:mm:ss
  final String endTime;

  ScheduleBlockModel({
    required this.id,
    required this.userId,
    required this.subject,
    this.location,
    this.teacher,
    this.color,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory ScheduleBlockModel.fromMap(Map<String, dynamic> m) {
    return ScheduleBlockModel(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      subject: m['subject'] as String,
      location: m['location'] as String?,
      teacher: m['teacher'] as String?,
      color: m['color'] as String?,
      dayOfWeek: (m['day_of_week'] as num).toInt(),
      startTime: m['start_time'].toString(),
      endTime: m['end_time'].toString(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'subject': subject,
      'location': location,
      'teacher': teacher,
      'color': color,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  int get startMinutes {
    final parts = startTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  int get endMinutes {
    final parts = endTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
