import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/pdf_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/routine_model.dart';
import '../../../shared/models/task_model.dart';
import '../../../shared/models/user_profile_model.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../today/providers/tasks_provider.dart';
import '../ai_planner.dart';
import '../providers/routines_provider.dart';

// ─── Domain models ──────────────────────────────────────────────────────────

class _SubjectFile {
  final String name;
  final String type;
  final int size;
  final String? fileUrl;
  final String? extractedText;

  const _SubjectFile({
    required this.name,
    required this.type,
    required this.size,
    this.fileUrl,
    this.extractedText,
  });

  bool get hasExtractedText =>
      extractedText != null && extractedText!.trim().isNotEmpty;

  Map<String, dynamic> toConfigMap() => {
        'name': name,
        'type': type,
        'size': size,
        'file_url': fileUrl,
        'has_extracted_text': hasExtractedText,
        'extracted_chars': extractedText?.length ?? 0,
      };

  Map<String, dynamic> toContextMap() => {
        'file': name,
        'type': type,
        'text': _truncate(extractedText ?? '', 12000),
      };
}

class _Subject {
  String name = '';
  DateTime? examDate;
  TimeOfDay? examTime;
  int difficulty = 3;
  Map<String, dynamic>? contentMap;
  final List<_SubjectFile> files = [];
}

// ─── Plan preview data ──────────────────────────────────────────────────────

class _PlanSummary {
  final String professorNote;
  final Map<String, _SubjectAnalysis> analysis;
  final int totalDays;
  final Map<String, int> hoursPerSubject;
  final Map<String, dynamic> rawPlan;

  _PlanSummary({
    required this.professorNote,
    required this.analysis,
    required this.totalDays,
    required this.hoursPerSubject,
    required this.rawPlan,
  });
}

class _SubjectAnalysis {
  final List<String> criticalTopics;
  final String technique;
  final String tip;

  _SubjectAnalysis({
    required this.criticalTopics,
    required this.technique,
    required this.tip,
  });
}

// ─── Wizard ─────────────────────────────────────────────────────────────────

class ExamsWizard extends ConsumerStatefulWidget {
  const ExamsWizard({super.key});

  @override
  ConsumerState<ExamsWizard> createState() => _ExamsWizardState();
}

class _ExamsWizardState extends ConsumerState<ExamsWizard> {
  // 0 = count, 1 = subjects, 2 = generating, 3 = preview
  int _step = 0;
  int _subjectCount = 1;
  final List<_Subject> _subjects = [_Subject()];
  _PlanSummary? _summary;
  bool _confirming = false;

  void _setCount(int n) {
    setState(() {
      _subjectCount = n;
      while (_subjects.length < n) {
        _subjects.add(_Subject());
      }
      while (_subjects.length > n) {
        _subjects.removeLast();
      }
    });
  }

  Future<void> _pickFiles(_Subject subject) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'docx',
          'txt',
          'md',
          'csv',
          'png',
          'jpg',
          'jpeg'
        ],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final pickedFiles = <_SubjectFile>[];
      var extractedCount = 0;

      for (final file in result.files) {
        final ext = _extensionFor(file);
        final extracted = await _extractText(file, ext);
        if (extracted != null && extracted.trim().isNotEmpty) extractedCount++;

        String? fileUrl;
        if (SupabaseService.instance.isConfigured &&
            SupabaseService.instance.isLoggedIn) {
          final user = SupabaseService.instance.currentUser;
          if (user != null && file.bytes != null) {
            try {
              fileUrl = await SupabaseService.instance.uploadNote(
                userId: user.id,
                fileName:
                    '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
                bytes: file.bytes!,
              );
            } catch (_) {}
          }
        }

        pickedFiles.add(_SubjectFile(
          name: file.name,
          type: ext,
          size: file.size,
          fileUrl: fileUrl,
          extractedText: extracted,
        ));
      }

      setState(() => subject.files.addAll(pickedFiles));
      if (!mounted) return;
      final uploadLabel =
          pickedFiles.any((f) => f.fileUrl != null) ? ' y subidos' : '';
      showSnack(
        context,
        '${pickedFiles.length} archivo(s) añadidos$uploadLabel · $extractedCount leídos',
      );
    } catch (e) {
      if (mounted) {
        showSnack(context, 'No se pudieron seleccionar los archivos',
            error: true);
      }
    }
  }

  Future<String?> _extractText(PlatformFile file, String ext) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    return PdfService.instance.extractTextFromBytes(bytes, extension: ext);
  }

  String _extensionFor(PlatformFile file) {
    final e = file.extension?.toLowerCase();
    if (e != null && e.isNotEmpty) return e;
    final parts = file.name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'file';
  }

  // ── Step 2 → Generate & Preview ──────────────────────────────────────────

  Future<void> _generatePreview() async {
    final valid = _subjects
        .where((s) => s.name.trim().isNotEmpty && s.examDate != null)
        .toList();
    if (valid.isEmpty) {
      showSnack(context, 'Añade al menos una asignatura con fecha.',
          error: true);
      return;
    }

    setState(() {
      _step = 2; // generating screen
    });

    try {
      final profile = ref.read(profileProvider).valueOrNull;
      final today = DateTime.now();
      for (final subject in valid) {
        subject.contentMap ??= await _buildContentMap(subject);
      }
      final subjectsPayload = valid
          .map((s) => _subjectPayload(s, includeExtractedText: true))
          .toList();
      final existingTasks = _existingTaskPayload();

      final plan = await AIPlanner.instance.generateJsonPlan(
        AIPlanner.instance.examPlanPrompt(
          subjects: subjectsPayload,
          today: today,
          profile: profile,
          existingTasks: existingTasks,
        ),
      );

      if (plan == null) {
        if (mounted) {
          showSnack(context,
              'No se pudo generar el plan con IA. Revisa tu conexión a Ollama / Anthropic.',
              error: true);
          setState(() {
            _step = 1;
          });
        }
        return;
      }

      // Build summary
      final professorNote =
          plan['professor_note']?.toString() ?? '¡Tu plan está listo!';
      final analysisRaw =
          plan['subject_analysis'] as Map<String, dynamic>? ?? {};
      final analysis = <String, _SubjectAnalysis>{};
      analysisRaw.forEach((k, v) {
        if (v is Map) {
          final criticals =
              List<String>.from((v['critical_topics'] as List?) ?? []);
          analysis[k] = _SubjectAnalysis(
            criticalTopics: criticals,
            technique: v['recommended_technique']?.toString() ?? '',
            tip: v['professor_tip']?.toString() ?? '',
          );
        }
      });

      final days = (plan['days'] as List?) ?? [];
      final hoursMap = <String, int>{};
      for (final day in days) {
        if (day is! Map) continue;
        for (final block in (day['blocks'] as List?) ?? []) {
          if (block is! Map) continue;
          final subj = block['subject']?.toString() ?? 'General';
          final mins = _asInt(block['minutes']) ?? 45;
          hoursMap[subj] = (hoursMap[subj] ?? 0) + mins;
        }
      }

      final summary = _PlanSummary(
        professorNote: professorNote,
        analysis: analysis,
        totalDays: days.length,
        hoursPerSubject: hoursMap,
        rawPlan: plan,
      );

      if (mounted) {
        setState(() {
          _summary = summary;
          _step = 3; // preview
        });
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Error: $e', error: true);
        setState(() {
          _step = 1;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _buildContentMap(_Subject subject) async {
    final notes = _combinedNotes(subject);
    if (notes.trim().isEmpty) {
      return {
        'topics': <Map<String, dynamic>>[],
        'total_estimated_hours': null,
        'difficulty_assessment':
            'Sin apuntes extraídos; el plan se basará en la dificultad y fecha de examen.',
      };
    }

    final map = await AIPlanner.instance.generateJsonPlan(
      AIPlanner.instance.contentMapPrompt(
        subject: subject.name.trim(),
        notes: notes,
      ),
      subject: subject.name.trim(),
    );

    return map ??
        {
          'topics': <Map<String, dynamic>>[],
          'total_estimated_hours': null,
          'difficulty_assessment':
              'No se pudo analizar el contenido con IA; usa los apuntes como contexto bruto.',
          'raw_notes_chars': notes.length,
        };
  }

  String _combinedNotes(_Subject subject) {
    final buffer = StringBuffer();
    for (final file in subject.files.where((file) => file.hasExtractedText)) {
      buffer
        ..writeln('--- Archivo: ${file.name} ---')
        ..writeln(file.extractedText)
        ..writeln();
    }
    return buffer.toString();
  }

  List<Map<String, dynamic>> _existingTaskPayload() {
    final tasks = ref.read(tasksProvider).valueOrNull ?? const <TaskModel>[];
    return tasks
        .where((task) =>
            !task.completed && task.dueDate != null && task.dueTime != null)
        .map((task) => {
              'id': task.id,
              'title': task.title,
              'date': task.dueDate!.toIso8601String().substring(0, 10),
              'time': task.dueTime,
              'category': task.category,
            })
        .toList();
  }

  // ── Confirm: create routine + tasks ──────────────────────────────────────

  Future<void> _confirmPlan() async {
    final plan = _summary?.rawPlan;
    if (plan == null) return;

    setState(() => _confirming = true);

    try {
      final valid = _subjects
          .where((s) => s.name.trim().isNotEmpty && s.examDate != null)
          .toList();
      final configSubjects = valid
          .map((s) => _subjectPayload(s, includeExtractedText: false))
          .toList();

      final routine = await ref.read(routinesProvider.notifier).create(
        type: RoutineType.exams,
        name: 'Exámenes (${valid.length})',
        config: {'subjects': configSubjects},
      );

      if (routine != null) await _saveNoteFilesMetadata(routine, valid);

      final days = (plan['days'] as List?) ?? [];
      for (final day in days) {
        if (day is! Map) continue;
        final dateStr = day['date']?.toString();
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;
        for (final rawBlock in (day['blocks'] as List?) ?? []) {
          if (rawBlock is! Map) continue;
          final block = Map<String, dynamic>.from(rawBlock);
          final subj = block['subject']?.toString().trim() ?? '';
          final topic = block['topic']?.toString().trim() ?? 'Estudio';
          final minutes = _asInt(block['minutes']) ?? 45;
          final dueTime = _timeFromBlock(block);
          await ref.read(tasksProvider.notifier).add(
                title:
                    '${subj.isEmpty ? 'Estudio' : subj} · ${_shorten(topic, 52)}',
                description: _buildDescription(block, date, minutes),
                dueDate: date,
                dueTime: dueTime,
                category: 'Estudio',
                routineId: routine?.id,
              );
        }
      }

      if (mounted) {
        showSnack(context,
            '✓ Plan creado con ${days.length} días de estudio personalizado');
        context.go('/routines');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _subjectPayload(_Subject s,
      {required bool includeExtractedText}) {
    return {
      'name': s.name.trim(),
      'exam_date': s.examDate!.toIso8601String().substring(0, 10),
      if (s.examTime != null)
        'exam_time':
            '${s.examTime!.hour.toString().padLeft(2, '0')}:${s.examTime!.minute.toString().padLeft(2, '0')}',
      'difficulty': s.difficulty,
      'files': s.files.map((f) => f.toConfigMap()).toList(),
      if (s.contentMap != null) 'content_map': s.contentMap,
      if (includeExtractedText)
        'notes_context': s.files
            .where((f) => f.hasExtractedText)
            .map((f) => f.toContextMap())
            .toList(),
    };
  }

  Future<void> _saveNoteFilesMetadata(
      RoutineModel routine, List<_Subject> subjects) async {
    if (!SupabaseService.instance.isConfigured ||
        !SupabaseService.instance.isLoggedIn) {
      return;
    }
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;
    final rows = <Map<String, dynamic>>[];
    for (final s in subjects) {
      for (final f in s.files.where((f) => f.fileUrl != null)) {
        rows.add({
          'user_id': user.id,
          'routine_id': routine.id,
          'subject': s.name.trim(),
          'file_url': f.fileUrl,
          'file_type': f.type,
          'extracted_text': f.extractedText,
        });
      }
    }
    if (rows.isEmpty) return;
    try {
      await SupabaseService.instance.client.from('notes_files').insert(rows);
    } catch (_) {}
  }

  String? _timeFromBlock(Map<String, dynamic> b) {
    final raw = (b['start'] ?? b['start_time'])?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    if (h == null || min == null || h > 23 || min > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:00';
  }

  String _buildDescription(Map<String, dynamic> b, DateTime date, int minutes) {
    final topic = b['topic']?.toString().trim() ?? 'Sesión de estudio';
    final subject = b['subject']?.toString().trim() ?? 'Estudio';
    final objective = _str(b['objective'] ?? b['detail'] ?? b['plan']) ??
        'Avanzar en el tema previsto para esta sesión.';
    final materials = _strList(
      b['materials'] ?? b['pages'] ?? b['page_range'] ?? b['slides'],
    );
    final steps = _strList(b['steps'] ?? b['tasks'] ?? b['checklist']);
    final tip = _str(b['tips'] ?? b['professor_tip'] ?? b['tip']);
    final technique = _str(b['technique']);
    final start = _str(b['start'] ?? b['start_time']);
    final end = _str(b['end'] ?? b['end_time']);

    return jsonEncode({
      'topic': topic,
      'subject': subject,
      'minutes': minutes,
      'date': date.toIso8601String().substring(0, 10),
      if (start != null)
        'start': start.length >= 5 ? start.substring(0, 5) : start,
      if (end != null) 'end': end.length >= 5 ? end.substring(0, 5) : end,
      'details': {
        'objective': objective,
        'materials': materials,
        'steps': steps,
        if (technique != null) 'technique': technique,
        'tips': tip ?? 'Haz una comprobación activa al terminar.',
      },
    });
  }

  int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '');
  }

  String? _str(Object? v) {
    if (v == null) return null;
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .join(', ');
    }
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  List<String> _strList(Object? v) {
    if (v == null) return const [];
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final t = v.toString().trim();
    if (t.isEmpty) return const [];
    return t
        .split(RegExp(r'\n+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _shorten(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1).trim()}…';
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutina de exámenes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step > 0 && _step < 3) {
              setState(() => _step = _step - 1);
            } else {
              context.go('/routines/new');
            }
          },
        ),
      ),
      body: LoadingOverlay(
        loading: _confirming,
        message: 'Creando tareas en tu calendario…',
        child: switch (_step) {
          0 => _StepCount(
              count: _subjectCount,
              onDecrement: () => _setCount(_subjectCount - 1),
              onIncrement: () => _setCount(_subjectCount + 1),
              onNext: () => setState(() => _step = 1),
            ),
          1 => _StepSubjects(
              subjects: _subjects,
              profile: profile,
              onPickFiles: _pickFiles,
              onGenerate: _generatePreview,
            ),
          2 => const _GeneratingScreen(),
          3 => _PlanPreview(
              summary: _summary!,
              onConfirm: _confirmPlan,
              onRegenerate: () => setState(() => _step = 1),
            ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

// ─── Step: Cantidad ──────────────────────────────────────────────────────────

class _StepCount extends StatelessWidget {
  final int count;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onNext;
  const _StepCount({
    required this.count,
    required this.onDecrement,
    required this.onIncrement,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text('¿Cuántas asignaturas?', style: t.textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          'El profesor IA creará un plan individualizado para cada una.',
          style: t.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 48),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.secondary.withValues(alpha: 0.10),
                  AppColors.accent.withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.outlined(
                  onPressed: count > 1 ? onDecrement : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 100,
                  child: Center(
                      child: Text('$count', style: t.textTheme.displayLarge)),
                ),
                IconButton.outlined(
                  onPressed: count < 12 ? onIncrement : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward, size: 20),
            label: const Text('Continuar'),
          ),
        ),
      ],
    );
  }
}

// ─── Step: Asignaturas ───────────────────────────────────────────────────────

class _StepSubjects extends StatefulWidget {
  final List<_Subject> subjects;
  final UserProfileModel? profile;
  final Future<void> Function(_Subject) onPickFiles;
  final VoidCallback onGenerate;
  const _StepSubjects({
    required this.subjects,
    required this.profile,
    required this.onPickFiles,
    required this.onGenerate,
  });

  @override
  State<_StepSubjects> createState() => _StepSubjectsState();
}

class _StepSubjectsState extends State<_StepSubjects> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final profile = widget.profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (profile != null) ...[
          _ProfessorBanner(
            name: profile.displayName,
            message:
                'Hola ${profile.displayName}, voy a analizar tus apuntes y crear un plan '
                'mensual completo adaptado a tu nivel. Sube los PDFs de cada asignatura para obtener '
                'el mejor resultado posible.',
          ),
          const SizedBox(height: 16),
        ],
        Text('Detalles de cada asignatura', style: t.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Cuantos más apuntes subas, más preciso será el plan. Los PDF y TXT se leen en local.',
          style: t.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < widget.subjects.length; i++)
          _SubjectCard(
            index: i,
            subject: widget.subjects[i],
            onPickFiles: () async {
              await widget.onPickFiles(widget.subjects[i]);
              setState(() {});
            },
            onChanged: () => setState(() {}),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: const Text('Analizar y generar plan mensual'),
            onPressed: widget.onGenerate,
          ),
        ),
      ],
    );
  }
}

class _ProfessorBanner extends StatelessWidget {
  final String name;
  final String message;
  const _ProfessorBanner({required this.name, required this.message});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.secondary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu Profesor IA',
                    style: t.textTheme.labelMedium
                        ?.copyWith(color: AppColors.primary)),
                const SizedBox(height: 4),
                Text(message,
                    style: t.textTheme.bodySmall?.copyWith(height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final int index;
  final _Subject subject;
  final VoidCallback onPickFiles;
  final VoidCallback onChanged;

  const _SubjectCard({
    required this.index,
    required this.subject,
    required this.onPickFiles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color =
        AppColors.subjectPalette[index % AppColors.subjectPalette.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Text('Asignatura ${index + 1}',
                  style: t.textTheme.titleSmall
                      ?.copyWith(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(labelText: 'Nombre'),
            onChanged: (v) {
              subject.name = v;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(subject.examDate == null
                      ? 'Fecha del examen'
                      : subject.examDate!.toIso8601String().substring(0, 10)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) {
                      subject.examDate = d;
                      onChanged();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(subject.examTime == null
                      ? 'Hora'
                      : subject.examTime!.format(context)),
                  onPressed: () async {
                    final t = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 9, minute: 0));
                    if (t != null) {
                      subject.examTime = t;
                      onChanged();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Dificultad',
                  style: t.textTheme.labelMedium
                      ?.copyWith(color: AppColors.textMuted)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${subject.difficulty}/5',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
          Slider(
            min: 1,
            max: 5,
            divisions: 4,
            value: subject.difficulty.toDouble(),
            onChanged: (v) {
              subject.difficulty = v.round();
              onChanged();
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file, size: 16),
            label: Text(subject.files.isEmpty
                ? 'Subir apuntes (PDF, TXT, MD…)'
                : 'Añadir más apuntes (${subject.files.length} añadido${subject.files.length > 1 ? 's' : ''})'),
            onPressed: onPickFiles,
          ),
          if (subject.files.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...subject.files.asMap().entries.map((entry) {
              final file = entry.value;
              return _FileChip(
                file: file,
                onRemove: () {
                  subject.files.removeAt(entry.key);
                  onChanged();
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final _SubjectFile file;
  final VoidCallback onRemove;
  const _FileChip({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final hasText = file.hasExtractedText;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: hasText
            ? AppColors.secondary.withValues(alpha: 0.08)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasText
              ? AppColors.secondary.withValues(alpha: 0.18)
              : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasText ? Icons.article_outlined : Icons.insert_drive_file_outlined,
            size: 18,
            color: hasText ? AppColors.secondary : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.labelMedium),
                Text(
                  hasText
                      ? '${file.extractedText!.length} caracteres listos para la IA'
                      : 'Sin texto extraído · referencia visual',
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ─── Generating screen ───────────────────────────────────────────────────────

class _GeneratingScreen extends StatefulWidget {
  const _GeneratingScreen();

  @override
  State<_GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<_GeneratingScreen> {
  int _msgIndex = 0;

  static const _messages = [
    'Leyendo tus apuntes…',
    'Analizando el contenido por asignatura…',
    'Identificando temas críticos…',
    'Diseñando la secuencia pedagógica…',
    'Aplicando spaced repetition…',
    'Calibrando la carga diaria…',
    'Generando el plan mensual…',
    'Casi listo…',
  ];

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);
      _tick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.secondary.withValues(alpha: 0.20),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.school, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            Text('Tu Profesor IA está trabajando',
                style: t.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _messages[_msgIndex],
                key: ValueKey(_msgIndex),
                style: t.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// ─── Plan preview ────────────────────────────────────────────────────────────

class _PlanPreview extends StatelessWidget {
  final _PlanSummary summary;
  final VoidCallback onConfirm;
  final VoidCallback onRegenerate;

  const _PlanPreview({
    required this.summary,
    required this.onConfirm,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final totalMins = summary.hoursPerSubject.values.fold(0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // Professor note
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Tu Profesor IA',
                      style: t.textTheme.labelLarge
                          ?.copyWith(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 10),
              Text(summary.professorNote,
                  style: t.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white, height: 1.55)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Stats row
        Row(
          children: [
            _StatCard(
              icon: Icons.calendar_month,
              value: '${summary.totalDays}',
              label: 'días de plan',
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            _StatCard(
              icon: Icons.timer_outlined,
              value: '${(totalMins / 60).round()}h',
              label: 'horas totales',
              color: AppColors.secondary,
            ),
            const SizedBox(width: 10),
            _StatCard(
              icon: Icons.menu_book_outlined,
              value: '${summary.hoursPerSubject.length}',
              label: 'asignaturas',
              color: AppColors.subjectPalette[3],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Hours per subject
        Text('Distribución de estudio', style: t.textTheme.titleMedium),
        const SizedBox(height: 12),
        ...summary.hoursPerSubject.entries
            .toList()
            .asMap()
            .entries
            .map((outer) {
          final i = outer.key;
          final e = outer.value;
          final color =
              AppColors.subjectPalette[i % AppColors.subjectPalette.length];
          final pct = totalMins == 0 ? 0.0 : e.value / totalMins;
          final hrs = (e.value / 60.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(e.key,
                            style: t.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis)),
                    Text(
                      '${hrs.toStringAsFixed(1)} h',
                      style: t.textTheme.labelMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }),

        // Subject analysis cards
        if (summary.analysis.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Análisis por asignatura', style: t.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...summary.analysis.entries.toList().asMap().entries.map((outer) {
            final i = outer.key;
            final e = outer.value;
            final color =
                AppColors.subjectPalette[i % AppColors.subjectPalette.length];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key,
                      style: t.textTheme.titleSmall?.copyWith(color: color)),
                  if (e.value.criticalTopics.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                        'Temas críticos: ${e.value.criticalTopics.take(3).join(', ')}',
                        style: t.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                  ],
                  if (e.value.technique.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Técnica recomendada: ${e.value.technique}',
                        style: t.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                  ],
                  if (e.value.tip.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(e.value.tip,
                              style:
                                  t.textTheme.bodySmall?.copyWith(height: 1.4)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],

        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRegenerate,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Regenerar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Crear plan en mi calendario'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: t.textTheme.titleLarge?.copyWith(color: color)),
            Text(label,
                style:
                    t.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _truncate(String text, int maxChars) {
  if (text.length <= maxChars) return text;
  return '${text.substring(0, maxChars)}\n\n[Truncado para mantener el contexto manejable]';
}
