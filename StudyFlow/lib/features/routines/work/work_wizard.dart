import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/routine_model.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../today/providers/tasks_provider.dart';
import '../ai_planner.dart';
import '../providers/routines_provider.dart';

class _Milestone {
  String description = '';
  DateTime? date;
}

class WorkWizard extends ConsumerStatefulWidget {
  const WorkWizard({super.key});

  @override
  ConsumerState<WorkWizard> createState() => _WorkWizardState();
}

class _WorkWizardState extends ConsumerState<WorkWizard> {
  final _name = TextEditingController();
  DateTime? _deadline;
  final List<_Milestone> _milestones = [];
  bool _generating = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_name.text.trim().isEmpty || _deadline == null) {
      showSnack(context, 'Nombre y fecha de entrega son obligatorios',
          error: true);
      return;
    }
    setState(() => _generating = true);
    try {
      final today = DateTime.now();
      final milestonesPayload = _milestones
          .where((m) => m.description.isNotEmpty && m.date != null)
          .map((m) => {
                'description': m.description,
                'date': m.date!.toIso8601String().substring(0, 10),
              })
          .toList();

      final routine = await ref.read(routinesProvider.notifier).create(
        type: RoutineType.work,
        name: _name.text.trim(),
        config: {
          'deadline': _deadline!.toIso8601String().substring(0, 10),
          'milestones': milestonesPayload,
        },
      );

      final plan = await AIPlanner.instance.generateJsonPlan(
        AIPlanner.instance.workPlanPrompt(
          projectName: _name.text.trim(),
          deadline: _deadline!,
          milestones: milestonesPayload,
          today: today,
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
            final task = b['task']?.toString() ?? '';
            final minutes = b['minutes'] is int ? b['minutes'] as int : 60;
            await ref.read(tasksProvider.notifier).add(
                  title: '$task ($minutes min)',
                  description: 'Proyecto: ${_name.text.trim()}',
                  dueDate: date,
                  category: 'Trabajo',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proyecto de trabajo')),
      body: LoadingOverlay(
        loading: _generating,
        message: 'Generando plan con IA...',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
                controller: _name,
                decoration:
                    const InputDecoration(labelText: 'Nombre del proyecto')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(_deadline == null
                  ? 'Fecha de entrega'
                  : 'Entrega: ${_deadline!.toIso8601String().substring(0, 10)}'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 14)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _deadline = d);
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                    child: Text('Hitos intermedios',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      setState(() => _milestones.add(_Milestone())),
                ),
              ],
            ),
            for (var i = 0; i < _milestones.length; i++) _milestoneCard(i),
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

  Widget _milestoneCard(int i) {
    final m = _milestones[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Descripción'),
              onChanged: (v) => m.description = v,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(m.date == null
                        ? 'Fecha objetivo'
                        : m.date!.toIso8601String().substring(0, 10)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.now().add(const Duration(days: 3)),
                        firstDate: DateTime.now(),
                        lastDate: _deadline ??
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => m.date = d);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _milestones.removeAt(i)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
