import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/models/schedule_block_model.dart';
import '../../../shared/models/task_model.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../today/providers/tasks_provider.dart';
import '../providers/schedule_provider.dart';

enum _ScheduleViewMode { day, week, month }

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late DateTime _weekStart;
  _ScheduleViewMode _mode = _ScheduleViewMode.week;

  @override
  void initState() {
    super.initState();
    _weekStart = AppDateUtils.weekDays(DateTime.now()).first;
  }

  void _moveWeek(int delta) {
    setState(() => _weekStart = _weekStart.add(Duration(days: delta * 7)));
  }

  void _goCurrentWeek() {
    setState(() => _weekStart = AppDateUtils.weekDays(DateTime.now()).first);
  }

  @override
  Widget build(BuildContext context) {
    final asyncBlocks = ref.watch(scheduleProvider);
    final asyncTasks = ref.watch(tasksProvider);
    final t = Theme.of(context);
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final weekLabel =
        '${DateFormat('d MMM', 'es').format(_weekStart)} - ${DateFormat('d MMM', 'es').format(weekEnd)}';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tu semana',
                          style: t.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted, letterSpacing: 0.3),
                        ),
                        const SizedBox(height: 6),
                        Text('Horario', style: t.textTheme.displaySmall),
                        const SizedBox(height: 4),
                        _WeekSelector(
                          label: weekLabel,
                          onPrevious: () => _moveWeek(-1),
                          onCurrent: _goCurrentWeek,
                          onNext: () => _moveWeek(1),
                        ),
                        SegmentedButton<_ScheduleViewMode>(
                          segments: const [
                            ButtonSegment(
                              value: _ScheduleViewMode.day,
                              label: Text('Día'),
                              icon: Icon(Icons.calendar_view_day),
                            ),
                            ButtonSegment(
                              value: _ScheduleViewMode.week,
                              label: Text('Semana'),
                              icon: Icon(Icons.calendar_view_week),
                            ),
                            ButtonSegment(
                              value: _ScheduleViewMode.month,
                              label: Text('Mes'),
                              icon: Icon(Icons.calendar_month),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (value) {
                            setState(() => _mode = value.first);
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _showEditor(context, ref, null),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            Expanded(
              child: asyncBlocks.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (blocks) => asyncTasks.when(
                  loading: () => _scheduleView(blocks, const []),
                  error: (_, __) => _scheduleView(blocks, const []),
                  data: (tasks) => _scheduleView(blocks, tasks),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleView(
    List<ScheduleBlockModel> blocks,
    List<TaskModel> tasks,
  ) {
    final weekTasks = _tasksForWeek(tasks, _weekStart);
    switch (_mode) {
      case _ScheduleViewMode.day:
        final today = DateTime.now();
        final day = today.isBefore(_weekStart) ||
                !today.isBefore(_weekStart.add(const Duration(days: 7)))
            ? _weekStart
            : today;
        return _DayScheduleView(
          day: day,
          blocks:
              blocks.where((block) => block.dayOfWeek == day.weekday).toList(),
          tasks: tasks.where((task) {
            final due = task.dueDate;
            return due != null && AppDateUtils.isSameDay(due, day);
          }).toList(),
          onTaskTap: (task) => context.go('/tasks/${task.id}'),
          onBlockTap: (block) => _showEditor(context, ref, block),
        );
      case _ScheduleViewMode.month:
        return _MonthScheduleView(
          reference: _weekStart,
          tasks: tasks,
          blocks: blocks,
          onTaskTap: (task) => context.go('/tasks/${task.id}'),
        );
      case _ScheduleViewMode.week:
        return _WeekGrid(
          blocks: blocks,
          tasks: weekTasks,
          weekStart: _weekStart,
          onCellTap: (day, hour) =>
              _showEditor(context, ref, null, day: day, hour: hour),
          onBlockTap: (block) => _showEditor(context, ref, block),
          onTaskTap: (task) => context.go('/tasks/${task.id}'),
          onTaskDrop: _moveTaskToSlot,
        );
    }
  }

  Future<void> _moveTaskToSlot(TaskModel task, int day, int hour) async {
    final date = _weekStart.add(Duration(days: day - 1));
    await ref.read(tasksProvider.notifier).update(task.id, {
      'due_date': date.toIso8601String().substring(0, 10),
      'due_time': '${hour.toString().padLeft(2, '0')}:00:00',
    });
  }

  List<TaskModel> _tasksForWeek(List<TaskModel> tasks, DateTime weekStart) {
    final start = AppDateUtils.startOfDay(weekStart);
    final end = start.add(const Duration(days: 7));
    return tasks.where((task) {
      final due = task.dueDate;
      if (due == null) return false;
      final day = AppDateUtils.startOfDay(due);
      return !day.isBefore(start) && day.isBefore(end);
    }).toList();
  }

  void _showEditor(
    BuildContext context,
    WidgetRef ref,
    ScheduleBlockModel? existing, {
    int? day,
    int? hour,
  }) {
    showDialog(
      context: context,
      builder: (_) => _BlockEditorDialog(
          existing: existing, defaultDay: day, defaultHour: hour),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onCurrent;
  final VoidCallback onNext;

  const _WeekSelector({
    required this.label,
    required this.onPrevious,
    required this.onCurrent,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        IconButton(
          tooltip: 'Semana anterior',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(label, style: t.textTheme.bodySmall),
        TextButton(onPressed: onCurrent, child: const Text('Semana actual')),
        IconButton(
          tooltip: 'Semana siguiente',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WeekGrid extends StatelessWidget {
  final List<ScheduleBlockModel> blocks;
  final List<TaskModel> tasks;
  final DateTime weekStart;
  final void Function(int day, int hour) onCellTap;
  final void Function(ScheduleBlockModel block) onBlockTap;
  final void Function(TaskModel task) onTaskTap;
  final void Function(TaskModel task, int day, int hour)? onTaskDrop;

  const _WeekGrid({
    required this.blocks,
    required this.tasks,
    required this.weekStart,
    required this.onCellTap,
    required this.onBlockTap,
    required this.onTaskTap,
    this.onTaskDrop,
  });

  static const _startHour = 7;
  static const _endHour = 22;
  static const _hourHeight = 56.0;
  static const _hourColumnWidth = 52.0;
  static const _dayColumnWidth = 110.0;

  @override
  Widget build(BuildContext context) {
    const dayCount = 7;
    final hours = List.generate(_endHour - _startHour, (i) => _startHour + i);
    final weekDays = AppDateUtils.weekDays(weekStart);
    final untimedTasks = tasks
        .where((task) => task.dueTime == null || task.dueTime!.isEmpty)
        .toList();
    final timedTasks = tasks
        .where((task) => task.dueTime != null && task.dueTime!.isNotEmpty)
        .toList();
    final t = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          child: SizedBox(
            width: _hourColumnWidth + dayCount * _dayColumnWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: _hourColumnWidth),
                    for (var d = 1; d <= dayCount; d++)
                      SizedBox(
                        width: _dayColumnWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Column(
                              children: [
                                Text(
                                  AppDateUtils.dayName(d),
                                  style: t.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3),
                                ),
                                Text(
                                  '${weekDays[d - 1].day}/${weekDays[d - 1].month}',
                                  style: t.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textMuted, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (untimedTasks.isNotEmpty) ...[
                  _UntimedTasksStrip(
                    tasks: untimedTasks,
                    onTaskTap: onTaskTap,
                  ),
                  const SizedBox(height: 8),
                ],
                Stack(
                  children: [
                    Column(
                      children: [
                        for (final h in hours)
                          Row(
                            children: [
                              SizedBox(
                                width: _hourColumnWidth,
                                height: _hourHeight,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(right: 8, top: 2),
                                  child: Text(
                                    '${h.toString().padLeft(2, '0')}:00',
                                    style: t.textTheme.bodySmall
                                        ?.copyWith(color: AppColors.textMuted),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              for (var d = 1; d <= dayCount; d++)
                                DragTarget<TaskModel>(
                                  onAcceptWithDetails: (details) =>
                                      onTaskDrop?.call(details.data, d, h),
                                  builder: (context, candidate, rejected) {
                                    return GestureDetector(
                                      onTap: () => onCellTap(d, h),
                                      child: Container(
                                        width: _dayColumnWidth,
                                        height: _hourHeight,
                                        decoration: BoxDecoration(
                                          color: candidate.isEmpty
                                              ? null
                                              : AppColors.secondary
                                                  .withValues(alpha: 0.06),
                                          border: Border(
                                            top: BorderSide(
                                              color: AppColors.borderSubtle,
                                              width: h == _startHour ? 1 : 0.5,
                                            ),
                                            left: BorderSide(
                                              color: AppColors.borderSubtle,
                                              width: d == 1 ? 1 : 0.5,
                                            ),
                                            right: d == dayCount
                                                ? const BorderSide(
                                                    color:
                                                        AppColors.borderSubtle,
                                                    width: 1)
                                                : BorderSide.none,
                                            bottom: h == _endHour - 1
                                                ? const BorderSide(
                                                    color:
                                                        AppColors.borderSubtle,
                                                    width: 1)
                                                : BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                      ],
                    ),
                    ..._buildBlocks(blocks),
                    ..._buildTasks(timedTasks),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBlocks(List<ScheduleBlockModel> blocks) {
    final widgets = <Widget>[];
    for (final block in blocks) {
      final startMin = block.startMinutes;
      final endMin = block.endMinutes;
      final top = ((startMin - _startHour * 60) / 60.0) * _hourHeight;
      final height = ((endMin - startMin) / 60.0) * _hourHeight;
      if (top < 0 || height <= 0) continue;
      final left =
          _hourColumnWidth + (block.dayOfWeek - 1) * _dayColumnWidth + 3;
      Color color = AppColors.primary;
      if (block.color != null) {
        try {
          color = Color(int.parse(block.color!.replaceFirst('#', '0xFF')));
        } catch (_) {}
      }
      widgets.add(Positioned(
        top: top + 1,
        left: left,
        width: _dayColumnWidth - 6,
        height: height - 2,
        child: GestureDetector(
          onTap: () => onBlockTap(block),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border(left: BorderSide(color: color, width: 3)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(block.subject,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                        fontSize: 12)),
                if (block.location != null && height > 50)
                  Text(block.location!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ));
    }
    return widgets;
  }

  List<Widget> _buildTasks(List<TaskModel> tasks) {
    final widgets = <Widget>[];
    final untimedCountByDay = <int, int>{};
    final sorted = [...tasks]..sort((a, b) {
        final ad = a.dueDate ?? DateTime(9999);
        final bd = b.dueDate ?? DateTime(9999);
        final cmp = ad.compareTo(bd);
        if (cmp != 0) return cmp;
        return (a.dueTime ?? '').compareTo(b.dueTime ?? '');
      });

    for (final task in sorted) {
      final due = task.dueDate;
      if (due == null) continue;
      final day = due.weekday;
      if (day < 1 || day > 7) continue;

      final hasTime = task.dueTime != null && task.dueTime!.isNotEmpty;
      final counter = untimedCountByDay[day] ?? 0;
      if (!hasTime) untimedCountByDay[day] = counter + 1;

      final startMin = hasTime
          ? _parseMinutes(task.dueTime!)
          : (_startHour * 60 + 8 + counter * 42);
      final duration = hasTime ? _durationMinutes(task).clamp(30, 180) : 36;
      final top = ((startMin - _startHour * 60) / 60.0) * _hourHeight;
      final double height = hasTime
          ? ((duration / 60.0) * _hourHeight).clamp(34.0, 140.0).toDouble()
          : 36.0;
      if (top < 0 || top > (_endHour - _startHour) * _hourHeight) continue;

      final color = _categoryColor(task.category);
      final left = _hourColumnWidth + (day - 1) * _dayColumnWidth + 10;
      widgets.add(Positioned(
        top: top + 3,
        left: left,
        width: _dayColumnWidth - 20,
        height: height,
        child: LongPressDraggable<TaskModel>(
          data: task,
          feedback: Material(
            color: Colors.transparent,
            child: _DragTaskFeedback(title: task.title, color: color),
          ),
          childWhenDragging: Opacity(
            opacity: 0.45,
            child: _TaskBlock(
              task: task,
              color: color,
              height: height,
              hasTime: hasTime,
              onTap: () => onTaskTap(task),
            ),
          ),
          child: _TaskBlock(
            task: task,
            color: color,
            height: height,
            hasTime: hasTime,
            onTap: () => onTaskTap(task),
          ),
        ),
      ));
    }
    return widgets;
  }

  int _parseMinutes(String hhmmss) {
    final parts = hhmmss.split(':');
    final hour = int.tryParse(parts[0]) ?? _startHour;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }

  int _durationMinutes(TaskModel task) {
    final text = '${task.description ?? ''}\n${task.title}';
    if (task.description != null) {
      try {
        final decoded = jsonDecode(task.description!);
        if (decoded is Map && decoded['minutes'] is num) {
          return (decoded['minutes'] as num).round();
        }
      } catch (_) {}
    }
    final match =
        RegExp(r'(?:Duración estimada:\s*)?(\d{2,3})\s*min').firstMatch(text);
    if (match == null) return 60;
    return int.tryParse(match.group(1)!) ?? 60;
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

class _TaskBlock extends StatelessWidget {
  final TaskModel task;
  final Color color;
  final double height;
  final bool hasTime;
  final VoidCallback onTap;

  const _TaskBlock({
    required this.task,
    required this.color,
    required this.height,
    required this.hasTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 5, 7, 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: task.completed ? 0.08 : 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(task.completed ? Icons.check_circle : Icons.task_alt,
                  size: 13, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: hasTime ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        decoration:
                            task.completed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (hasTime && height > 52)
                      Text(
                        task.dueTime!.substring(0, 5),
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragTaskFeedback extends StatelessWidget {
  final String title;
  final Color color;

  const _DragTaskFeedback({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _DayScheduleView extends StatelessWidget {
  final DateTime day;
  final List<ScheduleBlockModel> blocks;
  final List<TaskModel> tasks;
  final void Function(TaskModel task) onTaskTap;
  final void Function(ScheduleBlockModel block) onBlockTap;

  const _DayScheduleView({
    required this.day,
    required this.blocks,
    required this.tasks,
    required this.onTaskTap,
    required this.onBlockTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sortedTasks = [...tasks]
      ..sort((a, b) => (a.dueTime ?? '99:99').compareTo(b.dueTime ?? '99:99'));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(DateFormat("EEEE d 'de' MMMM", 'es').format(day),
            style: t.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (blocks.isNotEmpty) ...[
          Text('Bloques fijos', style: t.textTheme.labelLarge),
          const SizedBox(height: 8),
          ...blocks.map((block) => ListTile(
                tileColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.border),
                ),
                title: Text(block.subject),
                subtitle: Text(
                    '${block.startTime.substring(0, 5)} - ${block.endTime.substring(0, 5)}'),
                onTap: () => onBlockTap(block),
              )),
          const SizedBox(height: 16),
        ],
        Text('Tareas', style: t.textTheme.labelLarge),
        const SizedBox(height: 8),
        if (sortedTasks.isEmpty)
          Text('Sin tareas programadas',
              style:
                  t.textTheme.bodySmall?.copyWith(color: AppColors.textMuted))
        else
          ...sortedTasks.map((task) => ListTile(
                tileColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.border),
                ),
                title: Text(task.title),
                subtitle: Text(task.dueTime?.substring(0, 5) ?? 'Sin hora'),
                trailing: task.completed
                    ? const Icon(Icons.check_circle, color: AppColors.secondary)
                    : null,
                onTap: () => onTaskTap(task),
              )),
      ],
    );
  }
}

class _MonthScheduleView extends StatelessWidget {
  final DateTime reference;
  final List<TaskModel> tasks;
  final List<ScheduleBlockModel> blocks;
  final void Function(TaskModel task) onTaskTap;

  const _MonthScheduleView({
    required this.reference,
    required this.tasks,
    required this.blocks,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(reference.year, reference.month);
    final gridStart =
        monthStart.subtract(Duration(days: monthStart.weekday - 1));
    final days =
        List.generate(42, (index) => gridStart.add(Duration(days: index)));
    final t = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('MMMM yyyy', 'es').format(monthStart),
              style: t.textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              7,
              (index) => Expanded(
                child: Center(
                  child: Text(
                    AppDateUtils.dayName(index + 1),
                    style: t.textTheme.labelSmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.95,
              ),
              itemCount: days.length,
              itemBuilder: (_, index) {
                final day = days[index];
                final inMonth = day.month == reference.month;
                final dayTasks = tasks
                    .where((task) =>
                        task.dueDate != null &&
                        AppDateUtils.isSameDay(task.dueDate!, day))
                    .toList();
                final dayBlocks = blocks
                    .where((block) => block.dayOfWeek == day.weekday)
                    .length;
                return Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: inMonth
                        ? Theme.of(context).colorScheme.surface
                        : AppColors.surfaceAlt.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.day}',
                        style: t.textTheme.labelMedium?.copyWith(
                          color: inMonth
                              ? AppColors.textDark
                              : AppColors.textMuted,
                        ),
                      ),
                      if (dayBlocks > 0)
                        Text('$dayBlocks fijo${dayBlocks == 1 ? '' : 's'}',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textMuted)),
                      ...dayTasks.take(2).map((task) => InkWell(
                            onTap: () => onTaskTap(task),
                            child: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.secondary,
                              ),
                            ),
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UntimedTasksStrip extends StatelessWidget {
  final List<TaskModel> tasks;
  final void Function(TaskModel task) onTaskTap;

  const _UntimedTasksStrip({
    required this.tasks,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: _WeekGrid._hourColumnWidth + 7 * _WeekGrid._dayColumnWidth,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _WeekGrid._hourColumnWidth - 8,
            child: Text(
              'Sin hora',
              style: t.textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tasks.map((task) {
                final color = _categoryColor(task.category);
                final day = task.dueDate == null
                    ? ''
                    : '${AppDateUtils.dayName(task.dueDate!.weekday)} · ';
                return ActionChip(
                  avatar: Icon(Icons.task_alt, size: 14, color: color),
                  label: Text('$day${task.title}'),
                  onPressed: () => onTaskTap(task),
                  side: BorderSide(color: color.withValues(alpha: 0.25)),
                  backgroundColor: color.withValues(alpha: 0.08),
                );
              }).toList(),
            ),
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

class _BlockEditorDialog extends ConsumerStatefulWidget {
  final ScheduleBlockModel? existing;
  final int? defaultDay;
  final int? defaultHour;

  const _BlockEditorDialog({this.existing, this.defaultDay, this.defaultHour});

  @override
  ConsumerState<_BlockEditorDialog> createState() => _BlockEditorDialogState();
}

class _BlockEditorDialogState extends ConsumerState<_BlockEditorDialog> {
  late TextEditingController _subject;
  late TextEditingController _location;
  late TextEditingController _teacher;
  late int _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  Color _color = AppColors.subjectPalette.first;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _subject = TextEditingController(text: existing?.subject ?? '');
    _location = TextEditingController(text: existing?.location ?? '');
    _teacher = TextEditingController(text: existing?.teacher ?? '');
    _day = existing?.dayOfWeek ?? widget.defaultDay ?? 1;
    final defaultHour = widget.defaultHour ?? 9;
    _start = existing != null
        ? TimeOfDay(
            hour: int.parse(existing.startTime.split(':')[0]),
            minute: int.parse(existing.startTime.split(':')[1]))
        : TimeOfDay(hour: defaultHour, minute: 0);
    _end = existing != null
        ? TimeOfDay(
            hour: int.parse(existing.endTime.split(':')[0]),
            minute: int.parse(existing.endTime.split(':')[1]))
        : TimeOfDay(hour: defaultHour + 1, minute: 0);
    if (existing?.color != null) {
      try {
        _color = Color(int.parse(existing!.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _location.dispose();
    _teacher.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  String _hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  Future<void> _save() async {
    if (_subject.text.trim().isEmpty) return;
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) {
      if (mounted) showSnack(context, 'Inicia sesión primero', error: true);
      return;
    }
    final block = ScheduleBlockModel(
      id: widget.existing?.id ?? '',
      userId: userId,
      subject: _subject.text.trim(),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      teacher: _teacher.text.trim().isEmpty ? null : _teacher.text.trim(),
      color: _hex(_color),
      dayOfWeek: _day,
      startTime: _fmt(_start),
      endTime: _fmt(_end),
    );
    try {
      if (widget.existing == null) {
        await ref.read(scheduleProvider.notifier).add(block);
      } else {
        await ref.read(scheduleProvider.notifier).update(widget.existing!.id, {
          'subject': block.subject,
          'location': block.location,
          'teacher': block.teacher,
          'color': block.color,
          'day_of_week': block.dayOfWeek,
          'start_time': block.startTime,
          'end_time': block.endTime,
        });
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, 'Error: $e', error: true);
    }
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    await ref.read(scheduleProvider.notifier).delete(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.existing == null ? 'Nuevo bloque' : 'Editar bloque',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                TextField(
                    controller: _subject,
                    decoration: const InputDecoration(labelText: 'Asignatura')),
                const SizedBox(height: 10),
                TextField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: 'Aula')),
                const SizedBox(height: 10),
                TextField(
                    controller: _teacher,
                    decoration: const InputDecoration(labelText: 'Profesor')),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _day,
                  decoration: const InputDecoration(labelText: 'Día'),
                  items: List.generate(7, (i) => i + 1)
                      .map((d) => DropdownMenuItem(
                          value: d, child: Text(AppDateUtils.dayName(d))))
                      .toList(),
                  onChanged: (v) => setState(() => _day = v ?? 1),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text('Inicio: ${_start.format(context)}'),
                        onPressed: () async {
                          final p = await showTimePicker(
                              context: context, initialTime: _start);
                          if (p != null) setState(() => _start = p);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text('Fin: ${_end.format(context)}'),
                        onPressed: () async {
                          final p = await showTimePicker(
                              context: context, initialTime: _end);
                          if (p != null) setState(() => _end = p);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Color',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: AppColors.subjectPalette
                      .map((c) => GestureDetector(
                            onTap: () => setState(() => _color = c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: _color == c
                                        ? AppColors.textDark
                                        : Colors.transparent,
                                    width: 2.5),
                              ),
                              child: _color == c
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.existing != null)
                      TextButton(
                        onPressed: _delete,
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                        child: const Text('Eliminar'),
                      ),
                    const Spacer(),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                        onPressed: _save, child: const Text('Guardar')),
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
