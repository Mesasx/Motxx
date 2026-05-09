import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../shared/models/user_profile_context_model.dart';
import '../services/supabase_service.dart';

class AIContextManager {
  AIContextManager({UserProfileContextModel? profileContext})
      : _profileContext = profileContext;

  static final AIContextManager instance = AIContextManager();
  static const _cacheKey = 'user_profile_context';

  final UserProfileContextModel? _profileContext;

  Future<UserProfileContextModel?> loadCurrentContext() async {
    if (_profileContext != null) return _profileContext;

    try {
      if (SupabaseService.instance.isConfigured &&
          SupabaseService.instance.isLoggedIn) {
        final userId = SupabaseService.instance.currentUser!.id;
        final response = await SupabaseService.instance.client
            .from('user_profile_context')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (response != null) {
          return UserProfileContextModel.fromMap(
            Map<String, dynamic>.from(response),
          );
        }
      }
    } catch (_) {
      // Offline mode falls back to Hive below.
    }

    try {
      if (!Hive.isBoxOpen('settings')) return null;
      final raw = Hive.box('settings').get(_cacheKey) as String?;
      if (raw == null) return null;
      return UserProfileContextModel.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> buildSystemPrompt({String? subject}) async {
    return buildSystemPromptFromContext(
      await loadCurrentContext(),
      subject: subject,
    );
  }

  String buildSystemPromptFromContext(
    UserProfileContextModel? profileContext, {
    String? subject,
  }) {
    if (profileContext == null) {
      return _fallbackSystemPrompt(subject: subject);
    }

    final context = profileContext.context;
    final studies = _firstNotBlank([
      context['studies'],
      context['sector_role'],
      'su área de estudio o trabajo',
    ]);
    final educationLevel =
        _label(_educationLevels, context['education_level']) ?? 'su nivel';
    final currentYear = context['current_year']?.toString();
    final hours = _hoursLabel(profileContext);
    final concentration =
        _label(_timeWindows, context['concentration_window']) ??
            'su mejor franja disponible';
    final goal = _firstNotBlank([
      _label(_goals, context['primary_goal']),
      context['professional_goals'],
      'avanzar con criterio y sin perder tiempo',
    ]);
    final style =
        _label(_styles, context['study_style']) ?? context['study_style'];

    final subjectClause = subject == null || subject.trim().isEmpty
        ? ''
        : ', especializado en ${subject.trim()}';
    final yearClause = currentYear == null ? '' : ', curso $currentYear';
    final styleClause = style == null || style.toString().trim().isEmpty
        ? ''
        : ' Su estilo de estudio preferido es $style.';

    if (profileContext.profileType == ProfileType.professional) {
      return 'Eres un profesor experto y orientador académico-profesional de '
          '$studies$subjectClause. El usuario trabaja en $studies, dispone de '
          '$hours y su objetivo a 3-6 meses es $goal.$styleClause Responde '
          'como un mentor experto que conoce el campo al detalle. Sé conciso '
          'y accionable: el usuario tiene poco tiempo.';
    }

    if (profileContext.profileType == ProfileType.mixed) {
      final role = context['sector_role']?.toString();
      final roleClause =
          role == null || role.trim().isEmpty ? '' : ' y trabaja en $role';
      return 'Eres un profesor experto y orientador académico de $studies'
          '$subjectClause. El usuario es estudiante de $educationLevel'
          '$yearClause$roleClause, con $hours y prefiere estudiar por la '
          '$concentration. Su objetivo es $goal.$styleClause Responde como un '
          'profesor que conoce el temario al detalle, basándote en los apuntes '
          'proporcionados cuando estén disponibles. Sé conciso y accionable: '
          'el usuario tiene poco tiempo.';
    }

    return 'Eres un profesor experto y orientador académico de $studies'
        '$subjectClause. El usuario es estudiante de $educationLevel'
        '$yearClause, con $hours y prefiere estudiar por la $concentration. '
        'Su objetivo es $goal.$styleClause Responde como un profesor que '
        'conoce el temario al detalle, basándote en los apuntes proporcionados '
        'cuando estén disponibles. Sé conciso y accionable: el usuario tiene '
        'poco tiempo.';
  }

  Future<String> buildPlannerPrompt({
    required String request,
    String? subject,
    Map<String, dynamic> data = const {},
  }) async {
    return '''
${await buildSystemPrompt(subject: subject)}

=== PETICIÓN DE PLANIFICACIÓN ===
$request

=== DATOS DISPONIBLES ===
${jsonEncode(data)}

Devuelve una respuesta concreta, ordenada y accionable.
''';
  }

  Future<String> buildTutorPrompt(
    String subject,
    String notes,
    String question,
  ) async {
    return '''
${await buildSystemPrompt(subject: subject)}

=== APUNTES RELEVANTES ===
$notes

=== DUDA DEL USUARIO ===
$question

Explica la respuesta como profesor: primero idea central, luego ejemplo, y termina con una comprobación breve tipo examen.
''';
  }

  Future<String> buildSchedulerPrompt({
    required String request,
    Map<String, dynamic> data = const {},
  }) async {
    return '''
${await buildSystemPrompt()}

=== REGLAS DE ORIENTADOR ===
- Bloques de estudio de 25-50 minutos con descansos de 5-10 minutos.
- No más de 3 horas seguidas de estudio sin descanso largo.
- Asignaturas más difíciles en la mejor franja de concentración.
- Repaso espaciado: los temas vistos hace varios días deben reaparecer.
- Si la carga no es realista, dilo claramente y propone reducción de alcance.

=== PETICIÓN ===
$request

=== DATOS ===
${jsonEncode(data)}
''';
  }

  String _fallbackSystemPrompt({String? subject}) {
    final subjectClause = subject == null || subject.trim().isEmpty
        ? ''
        : ' de ${subject.trim()}';
    return 'Eres un profesor experto y orientador académico$subjectClause. '
        'Responde con criterio docente, basándote en los apuntes disponibles '
        'cuando existan. Sé conciso y accionable: el usuario tiene poco tiempo.';
  }

  String _hoursLabel(UserProfileContextModel profileContext) {
    final context = profileContext.context;
    if (profileContext.profileType == ProfileType.professional) {
      final hours = _num(context['professional_hours_per_day']);
      return hours == null ? 'tiempo limitado al día' : '${_fmt(hours)} h/día';
    }

    final weekday = _num(context['weekday_hours_per_day']);
    final weekend = _num(context['weekend_hours_per_day']);
    if (weekday == null && weekend == null) return 'tiempo limitado al día';
    if (weekend == null) return '${_fmt(weekday ?? 0)} h/día';
    return '${_fmt(weekday ?? 0)} h/día entre semana y ${_fmt(weekend)} h/día en fin de semana';
  }

  String _firstNotBlank(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return '';
  }

  String? _label(Map<String, String> labels, Object? value) {
    final key = value?.toString();
    if (key == null || key.isEmpty) return null;
    return labels[key] ?? key;
  }

  double? _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _fmt(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }
}

const _educationLevels = {
  'bachillerato': 'Bachillerato',
  'grado': 'Grado',
  'master': 'Máster',
  'fp': 'FP',
  'oposicion': 'Oposición',
  'otros': 'Otros',
};

const _timeWindows = {
  'manana': 'mañana',
  'tarde': 'tarde',
  'noche': 'noche',
};

const _goals = {
  'aprobar': 'aprobar',
  'nota_alta': 'sacar nota alta',
  'oposicion': 'preparar una oposición concreta',
  'aprender': 'entender a fondo',
  'mantener_ritmo': 'mantener ritmo sin quemarse',
};

const _styles = {
  'visual': 'visual',
  'escrito': 'escrito',
  'repeticion_espaciada': 'repetición espaciada',
  'mixto': 'mixto',
};
