import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/routine_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/routines_provider.dart';

class RoutinesScreen extends ConsumerWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRoutines = ref.watch(routinesProvider);
    final t = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/routines/new'),
        icon: const Icon(Icons.add),
        label: const Text('Crear rutina'),
      ),
      body: asyncRoutines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tus rutinas',
                            style: t.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMuted,
                                letterSpacing: 0.3)),
                        const SizedBox(height: 6),
                        Text('Planes con IA', style: t.textTheme.displaySmall),
                      ],
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.auto_awesome,
                    title: 'Sin rutinas todavía',
                    subtitle:
                        'Crea tu primera rutina y deja que\nla IA reparta el trabajo en tu calendario.',
                    action: ElevatedButton.icon(
                      onPressed: () => context.go('/routines/new'),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Crear rutina'),
                    ),
                  ),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(routinesProvider.notifier).fetch(),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tus rutinas',
                            style: t.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMuted,
                                letterSpacing: 0.3)),
                        const SizedBox(height: 6),
                        Text('Planes con IA', style: t.textTheme.displaySmall),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList.separated(
                    itemBuilder: (_, i) =>
                        _RoutineCard(routine: list[i], index: i),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: list.length,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoutineCard extends ConsumerWidget {
  final RoutineModel routine;
  final int index;
  const _RoutineCard({required this.routine, required this.index});

  IconData _iconFor(RoutineType type) {
    switch (type) {
      case RoutineType.exams:
        return Icons.school_outlined;
      case RoutineType.work:
        return Icons.work_outline;
      case RoutineType.sport:
        return Icons.fitness_center;
      case RoutineType.daily:
        return Icons.event_note_outlined;
    }
  }

  Color _colorFor(RoutineType type) {
    switch (type) {
      case RoutineType.exams:
        return AppColors.secondary;
      case RoutineType.work:
        return AppColors.subjectPalette[5];
      case RoutineType.sport:
        return AppColors.subjectPalette[1];
      case RoutineType.daily:
        return AppColors.subjectPalette[3];
    }
  }

  String _label(RoutineType type) {
    switch (type) {
      case RoutineType.exams:
        return 'Exámenes';
      case RoutineType.work:
        return 'Proyecto';
      case RoutineType.sport:
        return 'Deporte';
      case RoutineType.daily:
        return 'Organización diaria';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final color = _colorFor(routine.type);
    return Container(
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_iconFor(routine.type), color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(routine.name, style: t.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(_label(routine.type),
                    style: t.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          if (!routine.active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Pausada',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600)),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: AppColors.textMuted),
            onSelected: (v) {
              if (v == 'toggle') {
                ref
                    .read(routinesProvider.notifier)
                    .setActive(routine.id, !routine.active);
              }
              if (v == 'delete') {
                ref.read(routinesProvider.notifier).delete(routine.id);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'toggle',
                  child: Text(routine.active ? 'Pausar' : 'Activar')),
              const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}
