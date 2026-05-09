import 'dart:convert';

import '../../core/ai/ai_context_manager.dart';
import '../../core/ai/ai_service.dart';
import '../../shared/models/user_profile_model.dart';

class AIPlanner {
  AIPlanner._();
  static final AIPlanner instance = AIPlanner._();

  /// Sends a prompt and returns parsed JSON.
  Future<Map<String, dynamic>?> generateJsonPlan(
    String prompt, {
    String? subject,
  }) async {
    final systemPrompt =
        await AIContextManager.instance.buildSystemPrompt(subject: subject);
    final res = await AIService.instance.ask(
      systemPrompt: systemPrompt,
      userPrompt: prompt,
      jsonMode: true,
    );
    if (!res.ok || res.text.isEmpty) return null;
    return _safeParseJson(res.text);
  }

  Map<String, dynamic>? _safeParseJson(String raw) {
    final trimmed = raw.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    try {
      final v = jsonDecode(trimmed.substring(start, end + 1));
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // EXAMEN – Plan mensual con persona de profesor
  // ──────────────────────────────────────────────────────────────────────────

  String examPlanPrompt({
    required List<Map<String, dynamic>> subjects,
    required DateTime today,
    UserProfileModel? profile,
    List<Map<String, dynamic>> existingTasks = const [],
  }) {
    final studentCtx = profile?.toAIContext() ?? '';
    final maxH = profile?.maxStudyHoursPerDay ?? 3;
    final times = (profile?.preferredTimes ?? ['tarde']).map((t) {
      const map = {'manana': '7–13h', 'tarde': '13–20h', 'noche': '20–24h'};
      return map[t] ?? t;
    }).join(', ');

    // Detect subject domains for professor persona
    final subjectNames =
        subjects.map((s) => s['name']?.toString() ?? '').join(', ');

    return '''
Eres un catedrático experto con décadas de experiencia enseñando: $subjectNames.
Actúas como tutor personal y conoces en profundidad la pedagogía de cada materia.

$studentCtx

=== ASIGNATURAS Y CONTENIDO DISPONIBLE ===
${jsonEncode(subjects)}

=== TAREAS YA PROGRAMADAS (NO SOLAPAR) ===
${jsonEncode(existingTasks)}

=== TU MISIÓN ===
Diseña un PLAN DE ESTUDIO MENSUAL completo, personalizado y pedagógicamente sólido.
Aplica estos principios:
• Spaced repetition: sesiones de repaso cada 5-7 días
• Active recall: propón preguntas, no solo lectura pasiva
• Interleaving: alterna asignaturas para maximizar retención
• Progressive overload: dificultad creciente semana a semana

=== FASES DEL PLAN ===
FASE 1 – COMPRENSIÓN (primeras 2/3 del tiempo disponible):
  · Lectura activa de apuntes (subraya, anota preguntas al margen)
  · Elaboración de mapas conceptuales propios
  · Resúmenes en tus propias palabras (técnica Feynman)
  · Primeras preguntas tipo examen al finalizar cada tema

FASE 2 – PRÁCTICA (siguiente 20% del tiempo):
  · Ejercicios y problemas tipo examen
  · Flashcards para conceptos clave
  · Exámenes de práctica cronometrados
  · Revisión de errores frecuentes

FASE 3 – REPASO INTENSIVO (última semana):
  · Repaso general con cronómetro
  · Solo puntos débiles identificados
  · Resolución de dudas críticas
  · El día antes: máximo 2h de repaso ligero, nada nuevo

=== RESTRICCIONES IMPORTANTES ===
- Fecha de inicio: ${today.toIso8601String().substring(0, 10)}
- Máximo ${maxH}h de estudio por día
- Horario preferido: $times
- Respeta el horario: fines de semana máximo el 60% de horas de un día laboral
- No estudies una asignatura el mismo día de su examen
- Bloques de 25-50 minutos (técnica Pomodoro); indica inicio y fin
- Alterna asignaturas dentro del mismo día si hay más de una
- Usa técnicas específicas según la materia:
    · Programación / informática: incluye ejercicios de código prácticos
    · Matemáticas / física: resuelve problemas tipo, paso a paso
    · Historia / humanidades: cronologías, esquemas, asociaciones
    · Idiomas: vocabulario activo, práctica oral/escrita
    · Ciencias: flashcards de conceptos, diagramas

=== FORMATO DE RESPUESTA ===
Devuelve SOLO un JSON válido con esta estructura exacta:

{
  "professor_note": "Nota introductoria y motivadora del profesor (2-3 frases personalizadas para el estudiante)",
  "subject_analysis": {
    "<nombre asignatura>": {
      "key_topics": ["tema 1", "tema 2", "..."],
      "critical_topics": ["tema más importante 1", "..."],
      "recommended_technique": "técnica específica para esta materia",
      "professor_tip": "consejo concreto del profesor"
    }
  },
  "days": [
    {
      "date": "YYYY-MM-DD",
      "phase": "comprension|practica|repaso",
      "blocks": [
        {
          "subject": "Nombre exacto de la asignatura",
          "minutes": 45,
          "start": "HH:MM",
          "end": "HH:MM",
          "topic": "Tema muy concreto a estudiar hoy",
          "pages": "p. 12-28 o equivalente",
          "technique": "active_recall|lectura_activa|ejercicios|flashcards|resumen|mapa_mental|examen_practica|repaso",
          "professor_tip": "Consejo específico para este bloque de estudio",
          "tasks": ["tarea concreta 1", "tarea concreta 2", "tarea concreta 3"]
        }
      ]
    }
  ]
}
''';
  }

  String contentMapPrompt({
    required String subject,
    required String notes,
  }) {
    return '''
Eres un profesor de $subject. Analiza estos apuntes completos y devuelve SOLO un JSON válido con esta estructura:

{
  "topics": [
    {
      "name": "Nombre del tema",
      "weight": 1,
      "pages": "páginas exactas si aparecen",
      "slides": "diapositivas exactas si aparecen",
      "key_concepts": ["concepto 1", "concepto 2"]
    }
  ],
  "total_estimated_hours": 12,
  "difficulty_assessment": "evaluación breve de dificultad"
}

Sé exhaustivo: identifica TODOS los temas con sus páginas o diapositivas exactas cuando los apuntes las incluyan. Si una referencia no aparece, usa null o una cadena vacía.

=== APUNTES ===
$notes
''';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TRABAJO – Plan de proyecto
  // ──────────────────────────────────────────────────────────────────────────

  String workPlanPrompt({
    required String projectName,
    required DateTime deadline,
    required List<Map<String, dynamic>> milestones,
    required DateTime today,
    UserProfileModel? profile,
  }) {
    final studentCtx = profile?.toAIContext() ?? '';
    return '''
Eres un gestor de proyectos y coach de productividad experto.
$studentCtx

Proyecto: $projectName
Fecha de entrega: ${deadline.toIso8601String().substring(0, 10)}
Hoy: ${today.toIso8601String().substring(0, 10)}
Hitos intermedios: ${jsonEncode(milestones)}

Crea un plan diario detallado que lleve el proyecto de inicio a entrega.
Divide el trabajo en tareas concretas y accionables (no abstractas).
Aplica la técnica de bloques de trabajo profundo (deep work): bloques de 45-90 min sin distracciones.

Devuelve SOLO este JSON:
{
  "days": [
    {
      "date": "YYYY-MM-DD",
      "blocks": [
        { "task": "Descripción concreta y accionable", "minutes": 60, "deliverable": "qué tendrás listo al terminar" }
      ]
    }
  ]
}
''';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DEPORTE – Plan semanal con entrenador
  // ──────────────────────────────────────────────────────────────────────────

  String sportPlanPrompt({
    required String goal,
    required int daysPerWeek,
    required int sessionMinutes,
    UserProfileModel? profile,
  }) {
    final name = profile?.displayName ?? 'el estudiante';
    return '''
Eres un entrenador personal certificado. Tu alumno se llama $name.
Objetivo: $goal
Días por semana: $daysPerWeek
Minutos por sesión: $sessionMinutes

Diseña un plan semanal progresivo, con sesiones equilibradas entre grupos musculares / sistemas energéticos.
Incluye calentamiento y vuelta a la calma en cada sesión.
Aplica el principio de sobrecarga progresiva.

Devuelve SOLO este JSON:
{
  "week": [
    {
      "day": "Lunes",
      "session_type": "Tipo de sesión (fuerza/cardio/movilidad/descanso activo)",
      "session": "Descripción general de la sesión",
      "warm_up": "Calentamiento (5-10 min)",
      "exercises": [
        { "name": "Ejercicio", "sets": 3, "reps": "10-12", "rest": "60s", "tip": "técnica clave" }
      ],
      "cool_down": "Vuelta a la calma (5 min)"
    }
  ]
}
''';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DIARIO – Organización semanal
  // ──────────────────────────────────────────────────────────────────────────

  String dailyPlanPrompt({
    required List<Map<String, dynamic>> fixedActivities,
    required List<String> goals,
    required DateTime today,
    UserProfileModel? profile,
  }) {
    final studentCtx = profile?.toAIContext() ?? '';
    return '''
Eres un coach de productividad y gestión del tiempo.
$studentCtx

Hoy: ${today.toIso8601String().substring(0, 10)}
Actividades fijas (no modificar): ${jsonEncode(fixedActivities)}
Objetivos de la semana: ${jsonEncode(goals)}

Encaja los objetivos en los huecos libres de los 7 días próximos.
Agrupa tareas similares (batching). Respeta el horario preferido del usuario.
Incluye tiempo para descanso y recuperación.

Devuelve SOLO este JSON:
{
  "days": [
    {
      "date": "YYYY-MM-DD",
      "blocks": [
        { "title": "Tarea concreta", "start": "HH:MM", "end": "HH:MM", "category": "estudio|trabajo|deporte|personal|otro" }
      ]
    }
  ]
}
''';
  }
}
