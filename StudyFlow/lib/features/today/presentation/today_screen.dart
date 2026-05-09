import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/ai/ai_context_manager.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/task_model.dart';
import '../../../shared/models/user_profile_model.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../routines/providers/routines_provider.dart';
import '../../schedule/providers/schedule_provider.dart';
import '../providers/tasks_provider.dart';

// ─── Time-of-day grouping ────────────────────────────────────────────────────

enum _TimeSlot {
  morning('Mañana', '00:00', '12:59', Icons.wb_sunny_outlined),
  afternoon('Tarde', '13:00', '19:59', Icons.wb_cloudy_outlined),
  evening('Noche', '20:00', '23:59', Icons.nightlight_outlined),
  noTime('Sin hora', '', '', Icons.event_note_outlined);

  const _TimeSlot(this.label, this.from, this.to, this.icon);
  final String label;
  final String from;
  final String to;
  final IconData icon;
}

_TimeSlot _slotForTask(TaskModel t) {
  final time = t.dueTime;
  if (time == null || time.length < 5) return _TimeSlot.noTime;
  if (time.compareTo('13:00') < 0) return _TimeSlot.morning;
  if (time.compareTo('20:00') < 0) return _TimeSlot.afternoon;
  return _TimeSlot.evening;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with SingleTickerProviderStateMixin {
  String? _filterCategory;
  bool _adjustingWeek = false;
  late final AnimationController _progressCtrl;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncTasks = ref.watch(tasksProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final today = DateTime.now();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add, size: 22),
        label: const Text('Nueva tarea'),
        elevation: 3,
      ),
      body: LoadingOverlay(
        loading: _adjustingWeek,
        message: 'Tu orientador está ajustando la semana…',
        child: asyncTasks.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (all) {
            final todayTasks = all.where((task) {
              if (task.dueDate == null) {
                return false;
              }
              if (!AppDateUtils.isSameDay(task.dueDate!, today)) {
                return false;
              }
              if (_filterCategory != null && task.category != _filterCategory) {
                return false;
              }
              return true;
            }).toList()
              ..sort((a, b) =>
                  (a.dueTime ?? '99:99').compareTo(b.dueTime ?? '99:99'));

            final completed = todayTasks.where((t) => t.completed).length;
            final total = todayTasks.length;
            final pct = total == 0 ? 0.0 : completed / total;

            // Streak: consecutive days with ≥1 completed task (simplified: use completed today as proxy)
            final streak = _computeStreak(all);

            // Group by time slot
            final groups = <_TimeSlot, List<TaskModel>>{};
            for (final slot in _TimeSlot.values) {
              final tasks =
                  todayTasks.where((t) => _slotForTask(t) == slot).toList();
              if (tasks.isNotEmpty) {
                groups[slot] = tasks;
              }
            }

            return RefreshIndicator(
              onRefresh: () => ref.read(tasksProvider.notifier).fetch(),
              child: CustomScrollView(
                slivers: [
                  // ── Hero header ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _HeroHeader(
                      profile: profile,
                      today: today,
                      pct: pct,
                      completed: completed,
                      total: total,
                      streak: streak,
                      progressCtrl: _progressCtrl,
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _AdvisorCta(
                        onPressed: _adjustingWeek ? null : _adjustWeek,
                      ),
                    ),
                  ),

                  // ── Category filter ──────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _CategoryFilter(
                        selected: _filterCategory,
                        onSelect: (v) => setState(() => _filterCategory = v),
                      ),
                    ),
                  ),

                  // ── Task groups ──────────────────────────────────────────────
                  if (todayTasks.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 80),
                        child: EmptyState(
                          icon: Icons.check_circle_outline,
                          title: 'Día despejado',
                          subtitle:
                              'No tienes tareas para hoy.\nPulsa + para añadir una.',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final entries = groups.entries.toList();
                            final entry = entries[i];
                            return _TimeGroup(
                              slot: entry.key,
                              tasks: entry.value,
                              groupIndex: i,
                              onOpen: (t) => context.go('/tasks/${t.id}'),
                              onToggle: (t) =>
                                  ref.read(tasksProvider.notifier).toggle(t),
                              onDelete: (t) =>
                                  ref.read(tasksProvider.notifier).delete(t.id),
                            );
                          },
                          childCount: groups.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  int _computeStreak(List<TaskModel> all) {
    // Count how many consecutive past days (including today) have ≥1 completed
    final today = DateTime.now();
    var streak = 0;
    for (var i = 0; i < 60; i++) {
      final day = today.subtract(Duration(days: i));
      final hasCompleted = all.any((t) =>
          t.completed &&
          t.dueDate != null &&
          AppDateUtils.isSameDay(t.dueDate!, day));
      if (!hasCompleted) {
        break;
      }
      streak++;
    }
    return streak;
  }

  Future<void> _adjustWeek() async {
    setState(() => _adjustingWeek = true);
    try {
      final now = DateTime.now();
      final weekStart = AppDateUtils.weekDays(now).first;
      final weekEnd = weekStart.add(const Duration(days: 7));
      final tasks = ref.read(tasksProvider).valueOrNull ?? const <TaskModel>[];
      final routines =
          ref.read(routinesProvider).valueOrNull ?? const <dynamic>[];
      final schedule =
          ref.read(scheduleProvider).valueOrNull ?? const <dynamic>[];

      final pendingTasks = tasks
          .where((task) => !task.completed)
          .map((task) => {
                'id': task.id,
                'title': task.title,
                'description': task.description,
                'due_date': task.dueDate?.toIso8601String().substring(0, 10),
                'due_time': task.dueTime,
                'category': task.category,
                'routine_id': task.routineId,
              })
          .toList();
      final activeRoutines = routines
          .where((routine) => routine.active == true)
          .map((routine) => {
                'id': routine.id,
                'type': routine.type.value,
                'name': routine.name,
                'config': routine.config,
              })
          .toList();
      final fixedBlocks = schedule
          .map((block) => {
                'subject': block.subject,
                'day_of_week': block.dayOfWeek,
                'start_time': block.startTime,
                'end_time': block.endTime,
                'location': block.location,
              })
          .toList();

      final manager = AIContextManager.instance;
      final systemPrompt = await manager.buildSystemPrompt();
      final userPrompt = await manager.buildSchedulerPrompt(
        request:
            'Ajusta la semana actual (${weekStart.toIso8601String().substring(0, 10)} a ${weekEnd.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10)}). Devuelve SOLO JSON con advisor_message y days[].blocks[].',
        data: {
          'week_start': weekStart.toIso8601String().substring(0, 10),
          'week_end': weekEnd.toIso8601String().substring(0, 10),
          'active_routines': activeRoutines,
          'pending_tasks': pendingTasks,
          'fixed_schedule_blocks': fixedBlocks,
          'required_json_shape': {
            'advisor_message': 'consejo personalizado',
            'overload_warning': 'null o aviso si no es realista',
            'days': [
              {
                'date': 'YYYY-MM-DD',
                'blocks': [
                  {
                    'title': 'tarea accionable',
                    'subject': 'asignatura o área',
                    'start': 'HH:MM',
                    'end': 'HH:MM',
                    'minutes': 45,
                    'objective': 'objetivo concreto',
                    'steps': ['paso 1', 'paso 2'],
                    'materials': ['referencia si existe'],
                    'tips': 'consejo breve',
                    'category': 'Estudio'
                  }
                ]
              }
            ]
          },
        },
      );

      final response = await AIService.instance.ask(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        jsonMode: true,
      );
      if (!response.ok || response.text.trim().isEmpty) {
        if (mounted) {
          showSnack(context, response.error ?? 'La IA no devolvió propuesta',
              error: true);
        }
        return;
      }

      final plan = _parseAdvisorPlan(response.text);
      if (plan == null) {
        if (mounted) {
          showSnack(context, 'La propuesta no tenía un JSON válido',
              error: true);
        }
        return;
      }

      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (_) => _AdvisorPreviewDialog(plan: plan),
      );
      if (accepted == true) {
        await _applyAdvisorPlan(plan, weekStart, weekEnd);
        if (mounted) showSnack(context, 'Semana ajustada por tu orientador.');
      }
    } catch (error) {
      if (mounted) showSnack(context, 'Error: $error', error: true);
    } finally {
      if (mounted) setState(() => _adjustingWeek = false);
    }
  }

  Map<String, dynamic>? _parseAdvisorPlan(String raw) {
    final trimmed = raw.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(trimmed.substring(start, end + 1));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> _applyAdvisorPlan(
    Map<String, dynamic> plan,
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    final tasks = ref.read(tasksProvider).valueOrNull ?? const <TaskModel>[];
    final toReplace = tasks.where((task) {
      if (task.completed ||
          task.category != 'Estudio' ||
          task.dueDate == null) {
        return false;
      }
      final day = AppDateUtils.startOfDay(task.dueDate!);
      return !day.isBefore(weekStart) && day.isBefore(weekEnd);
    }).toList();

    for (final task in toReplace) {
      await ref.read(tasksProvider.notifier).delete(task.id);
    }

    final days = plan['days'] as List? ?? const [];
    for (final rawDay in days) {
      if (rawDay is! Map) continue;
      final day = Map<String, dynamic>.from(rawDay);
      final date = DateTime.tryParse(day['date']?.toString() ?? '');
      if (date == null) continue;
      final blocks = day['blocks'] as List? ?? const [];
      for (final rawBlock in blocks) {
        if (rawBlock is! Map) continue;
        final block = Map<String, dynamic>.from(rawBlock);
        final minutes = _asInt(block['minutes']) ?? 45;
        final subject = block['subject']?.toString() ?? 'Estudio';
        final title = block['title']?.toString() ?? 'Sesión de estudio';
        await ref.read(tasksProvider.notifier).add(
              title: '$subject · $title',
              description: jsonEncode({
                'topic': title,
                'subject': subject,
                'minutes': minutes,
                'date': date.toIso8601String().substring(0, 10),
                if (block['start'] != null) 'start': block['start'].toString(),
                if (block['end'] != null) 'end': block['end'].toString(),
                'details': {
                  'objective': block['objective']?.toString() ?? title,
                  'materials': _stringList(block['materials']),
                  'steps': _stringList(block['steps']),
                  'tips': block['tips']?.toString() ??
                      'Respeta el descanso antes de pasar al siguiente bloque.',
                },
              }),
              dueDate: date,
              dueTime: _timeForTask(block['start']),
              category: block['category']?.toString() ?? 'Estudio',
            );
      }
    }
    await ref.read(tasksProvider.notifier).fetch();
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  List<String> _stringList(Object? value) {
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

  String? _timeForTask(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
  }

  void _showAddDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _QuickAddDialog());
  }
}

class _AdvisorCta extends StatelessWidget {
  final VoidCallback? onPressed;

  const _AdvisorCta({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pídele a tu orientador que ajuste tu semana',
              style: t.textTheme.titleSmall,
            ),
          ),
          FilledButton(
            onPressed: onPressed,
            child: const Text('Ajustar'),
          ),
        ],
      ),
    );
  }
}

class _AdvisorPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> plan;

  const _AdvisorPreviewDialog({required this.plan});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final days = plan['days'] as List? ?? const [];
    final blockCount = days.fold<int>(0, (total, rawDay) {
      if (rawDay is! Map) return total;
      return total + ((rawDay['blocks'] as List?)?.length ?? 0);
    });
    final message = plan['advisor_message']?.toString() ??
        'He preparado una semana ajustada a tu carga.';
    final warning = plan['overload_warning']?.toString();

    return AlertDialog(
      title: const Text('Propuesta del orientador'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: t.textTheme.bodyMedium),
              if (warning != null && warning.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  warning,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                '$blockCount bloques propuestos',
                style: t.textTheme.titleSmall?.copyWith(
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              ...days.take(7).map((rawDay) {
                if (rawDay is! Map) return const SizedBox.shrink();
                final day = Map<String, dynamic>.from(rawDay);
                final blocks = day['blocks'] as List? ?? const [];
                if (blocks.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day['date']?.toString() ?? '',
                          style: t.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      ...blocks.take(4).map((rawBlock) {
                        if (rawBlock is! Map) return const SizedBox.shrink();
                        final block = Map<String, dynamic>.from(rawBlock);
                        return Text(
                          '${block['start'] ?? '--:--'} · ${block['subject'] ?? 'Estudio'} · ${block['title'] ?? ''}',
                          style: t.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Descartar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Aceptar plan'),
        ),
      ],
    );
  }
}

// ─── Hero header ─────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final UserProfileModel? profile;
  final DateTime today;
  final double pct;
  final int completed;
  final int total;
  final int streak;
  final AnimationController progressCtrl;

  const _HeroHeader({
    required this.profile,
    required this.today,
    required this.pct,
    required this.completed,
    required this.total,
    required this.streak,
    required this.progressCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName.split(' ').first ?? '';
    final greeting = _greeting(today.hour);
    final greetText = name.isNotEmpty ? '$greeting, $name' : greeting;
    final dateLabel = DateFormat("EEEE d 'de' MMMM", 'es').format(today);
    final dateCap = dateLabel[0].toUpperCase() + dateLabel.substring(1);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F6F53), Color(0xFF3F8F6B), Color(0xFF5AAB87)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date
            Text(
              dateCap,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            // Greeting
            Text(
              greetText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 24),
            // Progress ring + stats
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CircularProgress(
                  percent: pct,
                  controller: progressCtrl,
                  completed: completed,
                  total: total,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatRow(
                        icon: Icons.check_circle_outline,
                        label:
                            '$completed de $total ${total == 1 ? 'tarea' : 'tareas'}',
                      ),
                      const SizedBox(height: 10),
                      _StatRow(
                        icon: Icons.local_fire_department_outlined,
                        label: streak == 0
                            ? 'Empieza tu racha hoy'
                            : '$streak ${streak == 1 ? 'día' : 'días'} de racha',
                        highlight: streak > 0,
                      ),
                      const SizedBox(height: 10),
                      _StatRow(
                        icon: Icons.event_available_outlined,
                        label: total == 0
                            ? 'Sin tareas hoy'
                            : 'Pendientes: ${total - completed}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _greeting(int hour) {
    if (hour < 6) {
      return 'Buenas noches';
    }
    if (hour < 13) {
      return 'Buenos días';
    }
    if (hour < 20) {
      return 'Buenas tardes';
    }
    return 'Buenas noches';
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _StatRow(
      {required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final color = highlight ? const Color(0xFFFFD166) : Colors.white70;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Circular progress ring ───────────────────────────────────────────────────

class _CircularProgress extends StatelessWidget {
  final double percent;
  final AnimationController controller;
  final int completed;
  final int total;

  const _CircularProgress({
    required this.percent,
    required this.controller,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final animated =
            Curves.easeOutCubic.transform(controller.value) * percent;
        return SizedBox(
          width: 88,
          height: 88,
          child: CustomPaint(
            painter: _RingPainter(progress: animated),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(animated * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (total > 0)
                    Text(
                      '$completed/$total',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - 10) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Background ring
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─── Category filter ──────────────────────────────────────────────────────────

class _CategoryFilter extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  const _CategoryFilter({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cats = [null, ...AppConstants.defaultCategories];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = cats[i];
          final isSel = selected == c;
          return ChoiceChip(
            label: Text(c ?? 'Todas'),
            selected: isSel,
            onSelected: (_) => onSelect(c),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

// ─── Time group ───────────────────────────────────────────────────────────────

class _TimeGroup extends StatelessWidget {
  final _TimeSlot slot;
  final List<TaskModel> tasks;
  final int groupIndex;
  final ValueChanged<TaskModel> onOpen;
  final ValueChanged<TaskModel> onToggle;
  final ValueChanged<TaskModel> onDelete;

  const _TimeGroup({
    required this.slot,
    required this.tasks,
    required this.groupIndex,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final completedCount = tasks.where((t) => t.completed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(slot.icon, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              slot.label,
              style: t.textTheme.labelLarge?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$completedCount/${tasks.length}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...tasks.map((task) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TaskTile(
              task: task,
              onOpen: () => onOpen(task),
              onToggle: () => onToggle(task),
              onDelete: () => onDelete(task),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Task tile ────────────────────────────────────────────────────────────────

class _TaskTile extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = _categoryColor(task.category);

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: task.completed
                  ? t.colorScheme.surface.withValues(alpha: 0.6)
                  : t.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: task.completed
                    ? AppColors.border
                    : color.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: task.completed
                  ? []
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Color accent bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: task.completed ? AppColors.border : color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                // Checkbox
                _RoundCheckbox(
                    checked: task.completed, onTap: onToggle, color: color),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: t.textTheme.titleSmall?.copyWith(
                          decoration: task.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.completed
                              ? AppColors.textMuted
                              : AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (task.description != null &&
                          task.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description!,
                          style: t.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (task.category != null || task.dueTime != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (task.category != null)
                              _Pill(label: task.category!, color: color),
                            if (task.dueTime != null)
                              _Pill(
                                label: task.dueTime!.substring(0, 5),
                                icon: Icons.access_time,
                                color: AppColors.textMuted,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
        return AppColors.subjectPalette[3];
      case 'Deporte':
        return AppColors.subjectPalette[1];
      default:
        return AppColors.textMuted;
    }
  }
}

class _RoundCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  final Color color;
  const _RoundCheckbox(
      {required this.checked, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? color : Colors.transparent,
          border: Border.all(
            color: checked ? color : AppColors.border,
            width: 2,
          ),
        ),
        child: checked
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : const SizedBox.shrink(),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Quick-add dialog ─────────────────────────────────────────────────────────

class _QuickAddDialog extends ConsumerStatefulWidget {
  const _QuickAddDialog();

  @override
  ConsumerState<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends ConsumerState<_QuickAddDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String? _category;
  TimeOfDay? _time;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(tasksProvider.notifier).add(
            title: _title.text.trim(),
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            dueDate: DateTime.now(),
            dueTime: _time != null
                ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}:00'
                : null,
            category: _category,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Error: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nueva tarea',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                TextField(
                  controller: _title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _desc,
                  decoration:
                      const InputDecoration(labelText: 'Notas (opcional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Text('Categoría',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConstants.defaultCategories
                      .map((c) => ChoiceChip(
                            label: Text(c),
                            selected: _category == c,
                            onSelected: (s) =>
                                setState(() => _category = s ? c : null),
                            showCheckmark: false,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(_time == null
                            ? 'Sin hora'
                            : _time!.format(context)),
                        onPressed: () async {
                          final picked = await showTimePicker(
                              context: context, initialTime: TimeOfDay.now());
                          if (picked != null) {
                            setState(() => _time = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
