import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/routine_model.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../today/providers/tasks_provider.dart';
import '../ai_planner.dart';
import '../providers/routines_provider.dart';

class SportWizard extends ConsumerStatefulWidget {
  const SportWizard({super.key});

  @override
  ConsumerState<SportWizard> createState() => _SportWizardState();
}

class _SportWizardState extends ConsumerState<SportWizard> {
  String _goal = 'Mixto';
  int _daysPerWeek = 3;
  int _sessionMinutes = 45;
  bool _generating = false;

  static const _goals = ['Fuerza', 'Cardio', 'Flexibilidad', 'Mixto'];

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final routine = await ref.read(routinesProvider.notifier).create(
        type: RoutineType.sport,
        name: 'Deporte · $_goal',
        config: {
          'goal': _goal,
          'days_per_week': _daysPerWeek,
          'session_minutes': _sessionMinutes,
        },
      );

      final plan = await AIPlanner.instance.generateJsonPlan(
        AIPlanner.instance.sportPlanPrompt(
          goal: _goal,
          daysPerWeek: _daysPerWeek,
          sessionMinutes: _sessionMinutes,
        ),
      );

      if (plan != null && plan['week'] is List && routine != null) {
        final today = DateTime.now();
        final monday = today.subtract(Duration(days: today.weekday - 1));
        const weekDays = [
          'Lunes',
          'Martes',
          'Miércoles',
          'Jueves',
          'Viernes',
          'Sábado',
          'Domingo'
        ];
        for (final day in plan['week'] as List) {
          final dayName = day['day']?.toString() ?? '';
          final idx = weekDays
              .indexWhere((d) => d.toLowerCase() == dayName.toLowerCase());
          if (idx == -1) continue;
          final date = monday.add(Duration(days: idx));
          final exercises = (day['exercises'] as List?) ?? [];
          final desc = exercises
              .map((e) => '${e['name']} (${e['sets']}x${e['reps']})')
              .join(', ');
          await ref.read(tasksProvider.notifier).add(
                title: 'Sesión: ${day['session']?.toString() ?? _goal}',
                description: desc,
                dueDate: date,
                category: 'Deporte',
                routineId: routine.id,
              );
        }
        if (mounted) showSnack(context, 'Plan generado.');
      }
      if (mounted) context.go('/routines');
    } catch (e) {
      if (mounted) showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutina de deporte')),
      body: LoadingOverlay(
        loading: _generating,
        message: 'Generando plan con IA...',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Objetivo',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _goals
                  .map((g) => ChoiceChip(
                        label: Text(g),
                        selected: _goal == g,
                        onSelected: (_) => setState(() => _goal = g),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text('Días por semana: $_daysPerWeek',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              min: 1,
              max: 7,
              divisions: 6,
              value: _daysPerWeek.toDouble(),
              label: '$_daysPerWeek',
              onChanged: (v) => setState(() => _daysPerWeek = v.round()),
            ),
            Text('Minutos por sesión: $_sessionMinutes',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              min: 15,
              max: 120,
              divisions: 21,
              value: _sessionMinutes.toDouble(),
              label: '$_sessionMinutes min',
              onChanged: (v) => setState(() => _sessionMinutes = v.round()),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generar plan con IA'),
              onPressed: _generate,
            ),
          ],
        ),
      ),
    );
  }
}
