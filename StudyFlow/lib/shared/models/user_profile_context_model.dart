import 'dart:convert';

enum ProfileType {
  student('student'),
  professional('professional'),
  mixed('mixed');

  const ProfileType(this.value);
  final String value;

  static ProfileType fromString(String value) {
    return ProfileType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ProfileType.student,
    );
  }
}

class UserProfileContextModel {
  final String userId;
  final ProfileType profileType;
  final Map<String, dynamic> context;
  final bool onboardingCompleted;
  final DateTime updatedAt;

  const UserProfileContextModel({
    required this.userId,
    required this.profileType,
    required this.context,
    required this.onboardingCompleted,
    required this.updatedAt,
  });

  factory UserProfileContextModel.fromMap(Map<String, dynamic> map) {
    return UserProfileContextModel(
      userId: map['user_id'] as String? ?? 'local',
      profileType: ProfileType.fromString(
        map['profile_type'] as String? ?? ProfileType.student.value,
      ),
      context: Map<String, dynamic>.from(map['context'] as Map? ?? const {}),
      onboardingCompleted: map['onboarding_completed'] as bool? ?? false,
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'user_id': userId,
      'profile_type': profileType.value,
      'context': context,
      'onboarding_completed': onboardingCompleted,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toUpsertMap());

  String labelFor(String key) {
    final value = context[key];
    if (value == null) return '';
    if (value is List) {
      return value.map((item) => item.toString()).join(', ');
    }
    return value.toString();
  }

  double? numberFor(String key) {
    final value = context[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
