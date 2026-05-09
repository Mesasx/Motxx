import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/routine_model.dart';
import '../exams/exams_wizard.dart';
import '../work/work_wizard.dart';
import '../sport/sport_wizard.dart';
import '../daily/daily_wizard.dart';

class RoutineWizardScreen extends ConsumerStatefulWidget {
  const RoutineWizardScreen({super.key});

  @override
  ConsumerState<RoutineWizardScreen> createState() =>
      _RoutineWizardScreenState();
}

class _RoutineWizardScreenState extends ConsumerState<RoutineWizardScreen> {
  RoutineType? _selected;

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      switch (_selected!) {
        case RoutineType.exams:
          return const ExamsWizard();
        case RoutineType.work:
          return const WorkWizard();
        case RoutineType.sport:
          return const SportWizard();
        case RoutineType.daily:
          return const DailyWizard();
      }
    }

    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva rutina'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/routines'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            '¿Qué quieres organizar?',
            style: t.textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'La IA repartirá el trabajo en tu calendario.',
            style: t.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 28),
          _OptionCard(
            icon: Icons.school_outlined,
            color: AppColors.secondary,
            title: 'Exámenes',
            subtitle: 'Plan de estudio por asignatura y fecha de examen.',
            index: 0,
            onTap: () => setState(() => _selected = RoutineType.exams),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.work_outline,
            color: AppColors.subjectPalette[5],
            title: 'Proyecto de trabajo',
            subtitle: 'Reparte el proyecto en hitos y bloques diarios.',
            index: 1,
            onTap: () => setState(() => _selected = RoutineType.work),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.fitness_center,
            color: AppColors.subjectPalette[1],
            title: 'Deporte',
            subtitle: 'Plan semanal con ejercicios sugeridos.',
            index: 2,
            onTap: () => setState(() => _selected = RoutineType.sport),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.event_note_outlined,
            color: AppColors.subjectPalette[3],
            title: 'Organización diaria',
            subtitle: 'Encaja todos tus objetivos en la semana.',
            highlight: true,
            index: 3,
            onTap: () => setState(() => _selected = RoutineType.daily),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;
  final int index;

  const _OptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.index,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: highlight
                ? color.withValues(alpha: 0.06)
                : t.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  highlight ? color.withValues(alpha: 0.3) : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: t.textTheme.titleMedium),
                        if (highlight) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Recomendado',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: t.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
