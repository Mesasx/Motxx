import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/routine_model.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../today/providers/tasks_provider.dart';
import '../ai_planner.dart';
import '../providers/routines_provider.dart';

class _FixedActivity {
  String name = '';
  String day = 'Lunes';
  TimeOfDay? start;
  TimeOfDay? end;
}

class DailyWizard extends ConsumerStatefulWidget {
  const DailyWizard({super.key});

  @override
  ConsumerState<DailyWizard> createState() => _DailyWizardState();
}

class _DailyWizardState extends ConsumerState<DailyWizard> {
  final List<_FixedActivity> _activities = [];
  final List<TextEditingController> _goals = [TextEditingController()];
  bool _generating = false;

  static const _days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ];

  @override
  void dispose() {
    for (final c in _goals) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(TimeOfDay? t) => t == null
      ? '--:--'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final fixed = _activities
          .where((a) => a.name.isNotEmpty && a.start != null && a.end != null)
          .map((a) => {
                'name': a.name,
                'day': a.day,
                'start': _fmt(a.start),
                'end': _fmt(a.end),
              })
          .toList();
      final goals =
          _goals.map((c) => c.text.trim()).where((g) => g.isNotEmpty).toList();

      if (goals.isEmpty) {
        showSnack(context, 'Añade al menos un objetivo de la semana',
            error: true);
        return;
      }

      final routine = await ref.read(routinesProvider.notifier).create(
        type: RoutineType.daily,
        name: 'Organización diaria',
        config: {'fixed': fixed, 'goals': goals},
      );

      final plan = await AIPlanner.instance.generateJsonPlan(
        AIPlanner.instance.dailyPlanPrompt(
          fixedActivities: fixed,
          goals: goals,
          today: DateTime.now(),
        ),
      );

      if (plan != null && plan['days'] is List && routine != null) {
        for (final day in plan['days'] as List) {
          final dateStr = day['date']?.toString();
          if (dateStr == null) continue;
          final date = DateTime.tryParse(dateStr);
          if (date == null) continue;
          final blocks = (day['blocks'] as List?) ?? [];
          for (final b in blocks) {
            final title = b['title']?.toString() ?? '';
            final start = b['start']?.toString();
            final cat = b['category']?.toString() ?? 'Otros';
            await ref.read(tasksProvider.notifier).add(
                  title: title,
                  description: 'Plan diario',
                  dueDate: date,
                  dueTime: start != null ? '$start:00' : null,
                  category: _capitalize(cat),
                  routineId: routine.id,
                );
          }
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

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organización diaria')),
      body: LoadingOverlay(
        loading: _generating,
        message: 'Generando plan con IA...',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                    child: Text('Actividades fijas',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      setState(() => _activities.add(_FixedActivity())),
                ),
              ],
            ),
            for (var i = 0; i < _activities.length; i++) _activityCard(i),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                    child: Text('Objetivos de la semana',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      setState(() => _goals.add(TextEditingController())),
                ),
              ],
            ),
            for (var i = 0; i < _goals.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _goals[i],
                        decoration:
                            InputDecoration(labelText: 'Objetivo ${i + 1}'),
                      ),
                    ),
                    if (_goals.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() {
                          _goals[i].dispose();
                          _goals.removeAt(i);
                        }),
                      ),
                  ],
                ),
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

  Widget _activityCard(int i) {
    final a = _activities[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                  labelText: 'Nombre (ej: Clase, Trabajo, Sueño)'),
              onChanged: (v) => a.name = v,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: a.day,
                    decoration: const InputDecoration(labelText: 'Día'),
                    items: _days
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setState(() => a.day = v ?? 'Lunes'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 9, minute: 0));
                      if (t != null) setState(() => a.start = t);
                    },
                    child: Text('Inicio: ${_fmt(a.start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 10, minute: 0));
                      if (t != null) setState(() => a.end = t);
                    },
                    child: Text('Fin: ${_fmt(a.end)}'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _activities.removeAt(i)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
