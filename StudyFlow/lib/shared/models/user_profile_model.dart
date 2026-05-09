import 'dart:convert';

class UserProfileModel {
  static const Map<String, String> levels = {
    'eso': 'ESO / Secundaria',
    'bachillerato': 'Bachillerato',
    'fp': 'Formación Profesional',
    'grado': 'Grado Universitario',
    'master': 'Máster',
    'doctorado': 'Doctorado',
    'oposicion': 'Oposición / Certificación',
    'autodidacta': 'Aprendizaje autónomo',
    'otros': 'Otros',
  };

  static const Map<String, String> goals = {
    'aprobar': 'Aprobar con buena nota',
    'excelencia': 'Alcanzar la excelencia',
    'nota_alta': 'Sacar nota alta',
    'aprender': 'Aprender en profundidad',
    'trabajo': 'Mejorar mis habilidades profesionales',
    'oposicion': 'Preparar una oposición o certificación',
    'mantener_ritmo': 'Mantener ritmo sin quemarme',
  };

  static const Map<String, String> styles = {
    'visual': 'Visual — diagramas y mapas mentales',
    'escrito': 'Escrito — resúmenes y desarrollo',
    'repeticion_espaciada': 'Repetición espaciada — repasos programados',
    'practico': 'Práctico — ejercicios y proyectos',
    'teorico': 'Teórico — lectura y resúmenes',
    'mixto': 'Mixto — combinar varios métodos',
  };

  static const Map<String, String> timeLabels = {
    'manana': 'Mañana (7–13h)',
    'tarde': 'Tarde (13–20h)',
    'noche': 'Noche (20–24h)',
  };

  final String userId;
  final String displayName;
  final String? institution;
  final String level;
  final String? degree;
  final int? yearOfStudy;
  final List<String> subjects;
  final String primaryGoal;
  final String studyStyle;
  final int weeklyHoursAvailable;
  final List<String> preferredTimes;
  final List<String> weakTopics;
  final String? extraContext;
  final DateTime createdAt;

  const UserProfileModel({
    required this.userId,
    required this.displayName,
    this.institution,
    this.level = 'grado',
    this.degree,
    this.yearOfStudy,
    this.subjects = const [],
    this.primaryGoal = 'aprobar',
    this.studyStyle = 'mixto',
    this.weeklyHoursAvailable = 10,
    this.preferredTimes = const ['tarde'],
    this.weakTopics = const [],
    this.extraContext,
    required this.createdAt,
  });

  factory UserProfileModel.fromMap(Map<String, dynamic> m) {
    List<String> toList(dynamic v) =>
        v == null ? [] : List<String>.from(v as List);
    return UserProfileModel(
      userId: m['user_id'] as String? ?? 'local',
      displayName: m['display_name'] as String? ?? '',
      institution: m['institution'] as String?,
      level: m['level'] as String? ?? 'grado',
      degree: m['degree'] as String?,
      yearOfStudy: m['year_of_study'] as int?,
      subjects: toList(m['subjects']),
      primaryGoal: m['primary_goal'] as String? ?? 'aprobar',
      studyStyle: m['study_style'] as String? ?? 'mixto',
      weeklyHoursAvailable: m['weekly_hours'] as int? ?? 10,
      preferredTimes: toList(m['preferred_times']),
      weakTopics: toList(m['weak_topics']),
      extraContext: m['extra_context'] as String?,
      createdAt:
          DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'user_id': userId,
        'display_name': displayName,
        'institution': institution,
        'level': level,
        'degree': degree,
        'year_of_study': yearOfStudy,
        'subjects': subjects,
        'primary_goal': primaryGoal,
        'study_style': studyStyle,
        'weekly_hours': weeklyHoursAvailable,
        'preferred_times': preferredTimes,
        'weak_topics': weakTopics,
        'extra_context': extraContext,
        'created_at': createdAt.toIso8601String(),
      };

  String toJsonString() => jsonEncode(toInsertMap());

  UserProfileModel copyWith({
    String? displayName,
    String? institution,
    String? level,
    String? degree,
    int? yearOfStudy,
    List<String>? subjects,
    String? primaryGoal,
    String? studyStyle,
    int? weeklyHoursAvailable,
    List<String>? preferredTimes,
    List<String>? weakTopics,
    String? extraContext,
  }) =>
      UserProfileModel(
        userId: userId,
        displayName: displayName ?? this.displayName,
        institution: institution ?? this.institution,
        level: level ?? this.level,
        degree: degree ?? this.degree,
        yearOfStudy: yearOfStudy ?? this.yearOfStudy,
        subjects: subjects ?? this.subjects,
        primaryGoal: primaryGoal ?? this.primaryGoal,
        studyStyle: studyStyle ?? this.studyStyle,
        weeklyHoursAvailable: weeklyHoursAvailable ?? this.weeklyHoursAvailable,
        preferredTimes: preferredTimes ?? this.preferredTimes,
        weakTopics: weakTopics ?? this.weakTopics,
        extraContext: extraContext ?? this.extraContext,
        createdAt: createdAt,
      );

  bool get isComplete => displayName.isNotEmpty && subjects.isNotEmpty;

  int get maxStudyHoursPerDay =>
      ((weeklyHoursAvailable / 6).clamp(1.0, 6.0)).round();

  /// Rich context string injected into every AI prompt.
  String toAIContext() {
    final levelLabel = levels[level] ?? level;
    final goalLabel = goals[primaryGoal] ?? primaryGoal;
    final styleLabel = styles[studyStyle] ?? studyStyle;
    final timesLabel = preferredTimes.map((t) => timeLabels[t] ?? t).join(', ');

    final buf = StringBuffer();
    buf.writeln('=== PERFIL DEL ESTUDIANTE ===');
    buf.writeln('Nombre: $displayName');
    if (institution != null) buf.writeln('Institución: $institution');
    buf.write('Nivel: $levelLabel');
    if (degree != null) buf.write(' · $degree');
    if (yearOfStudy != null) buf.write(' ($yearOfStudy.º año)');
    buf.writeln();
    buf.writeln('Objetivo: $goalLabel');
    buf.writeln('Estilo de aprendizaje: $styleLabel');
    buf.writeln('Horas disponibles/semana: $weeklyHoursAvailable h');
    buf.writeln('Máximo por día: $maxStudyHoursPerDay h');
    buf.writeln('Horarios preferidos: $timesLabel');
    if (subjects.isNotEmpty) {
      buf.writeln('Asignaturas actuales: ${subjects.join(', ')}');
    }
    if (weakTopics.isNotEmpty) {
      buf.writeln('Áreas de mejora declaradas: ${weakTopics.join(', ')}');
    }
    if (extraContext != null && extraContext!.isNotEmpty) {
      buf.writeln('Contexto adicional: $extraContext');
    }
    buf.writeln('===');
    return buf.toString();
  }
}
