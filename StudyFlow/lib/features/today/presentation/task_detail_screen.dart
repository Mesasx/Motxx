import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/task_model.dart';
import '../providers/tasks_provider.dart';

class TaskDetailScreen extends ConsumerWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTasks = ref.watch(tasksProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de tarea'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/today'),
        ),
      ),
      body: asyncTasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tasks) {
          final task = tasks.where((t) => t.id == taskId).firstOrNull;
          if (task == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off,
                        size: 44, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text('Tarea no encontrada',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextButton(
                        onPressed: () => context.go('/today'),
                        child: const Text('Volver a Hoy')),
                  ],
                ),
              ),
            );
          }
          return _TaskDetail(task: task);
        },
      ),
    );
  }
}

class _TaskDetail extends ConsumerWidget {
  final TaskModel task;
  const _TaskDetail({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final color = _categoryColor(task.category);
    final dateLabel = task.dueDate == null
        ? 'Sin fecha'
        : DateFormat("EEEE d 'de' MMMM", 'es').format(task.dueDate!);

    return RefreshIndicator(
      onRefresh: () => ref.read(tasksProvider.notifier).fetch(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.12),
                  AppColors.secondary.withValues(alpha: 0.08)
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                          task.completed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: color),
                    ),
                    const Spacer(),
                    if (task.category != null)
                      _Pill(label: task.category!, color: color),
                    if (task.dueTime != null) ...[
                      const SizedBox(width: 8),
                      _Pill(
                          label: task.dueTime!.substring(0, 5),
                          color: AppColors.textMuted,
                          icon: Icons.access_time),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Text(task.title, style: t.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  dateLabel[0].toUpperCase() + dateLabel.substring(1),
                  style: t.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (task.description != null && task.description!.trim().isNotEmpty)
            _PlanCard(description: task.description!, color: color)
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Text('Sin plan detallado todavía.',
                  style: t.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textMuted)),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(tasksProvider.notifier).toggle(task),
                  icon: Icon(task.completed ? Icons.undo : Icons.check),
                  label: Text(task.completed
                      ? 'Marcar pendiente'
                      : 'Marcar completada'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Modo enfoque',
                onPressed: () => context.go('/focus/${task.id}'),
                icon: const Icon(Icons.timer_outlined),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Eliminar',
                onPressed: () async {
                  await ref.read(tasksProvider.notifier).delete(task.id);
                  if (context.mounted) context.go('/today');
                },
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String? cat) {
    switch (cat) {
      case 'Estudio':
        return AppColors.secondary;
      case 'Trabajo':
        return AppColors.subjectPalette[5];
      case 'Personal':
        return AppColors.subjectPalette[4];
      case 'Deporte':
        return AppColors.subjectPalette[2];
      default:
        return AppColors.primary;
    }
  }
}

class _PlanCard extends StatelessWidget {
  final String description;
  final Color color;
  const _PlanCard({required this.description, required this.color});

  @override
  Widget build(BuildContext context) {
    final structured = _tryParseStudyPlan(description);
    if (structured != null) {
      return _StructuredPlanCard(plan: structured, color: color);
    }

    final t = Theme.of(context);
    final lines = description.split('\n');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Text('Plan completo', style: t.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          ...lines.map((line) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) return const SizedBox(height: 10);
            if (trimmed == 'Detalle:' || trimmed == 'Pasos:') {
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(trimmed.replaceAll(':', ''),
                    style: t.textTheme.titleSmall?.copyWith(color: color)),
              );
            }
            if (trimmed.startsWith('•')) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w700)),
                    Expanded(
                        child: Text(trimmed.substring(1).trim(),
                            style: t.textTheme.bodyMedium)),
                  ],
                ),
              );
            }
            final separator = trimmed.indexOf(':');
            if (separator > 0 && separator < 28) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: RichText(
                  text: TextSpan(
                    style: t.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                          text: '${trimmed.substring(0, separator)}: ',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: color)),
                      TextSpan(text: trimmed.substring(separator + 1).trim()),
                    ],
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText(trimmed, style: t.textTheme.bodyMedium),
            );
          }),
        ],
      ),
    );
  }

  Map<String, dynamic>? _tryParseStudyPlan(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (!map.containsKey('details')) return null;
      return map;
    } catch (_) {
      return null;
    }
  }
}

class _StructuredPlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final Color color;

  const _StructuredPlanCard({required this.plan, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final details = Map<String, dynamic>.from(plan['details'] as Map? ?? {});
    final materials = _list(details['materials']);
    final steps = _list(details['steps']);
    final tips = details['tips']?.toString();
    final technique = details['technique']?.toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan['subject']?.toString() ?? 'Estudio',
                  style: t.textTheme.titleMedium,
                ),
              ),
              if (plan['minutes'] != null)
                _Pill(label: '${plan['minutes']} min', color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            plan['topic']?.toString() ?? 'Sesión de estudio',
            style: t.textTheme.titleSmall?.copyWith(color: color),
          ),
          const SizedBox(height: 10),
          _InfoLine(
            label: 'Objetivo',
            value: details['objective']?.toString() ?? '',
            color: color,
          ),
          if (technique != null && technique.isNotEmpty)
            _InfoLine(label: 'Técnica', value: technique, color: color),
          if (materials.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Materiales', style: t.textTheme.titleSmall),
            const SizedBox(height: 6),
            ...materials.map(
              (material) => _Bullet(text: material, color: color),
            ),
          ],
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Pasos', style: t.textTheme.titleSmall),
            const SizedBox(height: 6),
            ...steps.map((step) => _Bullet(text: step, color: color)),
          ],
          if (tips != null && tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: _InfoLine(label: 'Consejo', value: tips, color: color),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _list(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return const [];
    return [text];
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoLine({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          style: t.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final Color color;

  const _Bullet({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Pill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class FocusModeScreen extends ConsumerStatefulWidget {
  final String taskId;

  const FocusModeScreen({super.key, required this.taskId});

  @override
  ConsumerState<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends ConsumerState<FocusModeScreen> {
  Timer? _timer;
  late int _remainingSeconds;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 25 * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _running = false;
        });
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = ref
        .watch(tasksProvider)
        .valueOrNull
        ?.where((task) => task.id == widget.taskId)
        .firstOrNull;
    if (task == null) {
      return const Scaffold(body: Center(child: Text('Tarea no encontrada')));
    }

    final plan = _parsePlan(task.description);
    final minutes =
        plan?['minutes'] is num ? (plan!['minutes'] as num).round() : 25;
    if (_remainingSeconds == 25 * 60 && minutes != 25) {
      _remainingSeconds = minutes * 60;
    }
    final steps = _steps(plan);
    final time =
        '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo enfoque'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/tasks/${task.id}'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  time,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: FilledButton.icon(
                  onPressed: _toggle,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? 'Pausar' : 'Empezar'),
                ),
              ),
              const SizedBox(height: 28),
              Text('Plan paso a paso',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: steps.isEmpty
                      ? [
                          Text(
                            task.description ?? 'Sin pasos definidos.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        ]
                      : steps
                          .map(
                            (step) => ListTile(
                              leading: const Icon(Icons.check_circle_outline,
                                  color: AppColors.secondary),
                              title: Text(step),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _parsePlan(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  List<String> _steps(Map<String, dynamic>? plan) {
    final details = plan?['details'];
    if (details is! Map) return const [];
    final steps = details['steps'];
    if (steps is! List) return const [];
    return steps.map((step) => step.toString()).toList();
  }
}
