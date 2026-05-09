import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/routine_model.dart';
import '../../routines/providers/routines_provider.dart';
import '../../today/providers/tasks_provider.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _query = TextEditingController();
  String _term = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).valueOrNull ?? const [];
    final routines = ref.watch(routinesProvider).valueOrNull ?? const [];
    final term = _term.toLowerCase().trim();
    final matchingTasks = term.isEmpty
        ? const []
        : tasks.where((task) {
            final haystack =
                '${task.title} ${task.description ?? ''} ${task.category ?? ''}'
                    .toLowerCase();
            return haystack.contains(term);
          }).toList();
    final matchingRoutines = term.isEmpty
        ? const []
        : routines.where((routine) {
            final haystack =
                '${routine.name} ${routine.type.value} ${jsonEncode(routine.config)}'
                    .toLowerCase();
            return haystack.contains(term);
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextField(
            controller: _query,
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar tarea, asignatura o rutina',
            ),
            onChanged: (value) => setState(() => _term = value),
          ),
          const SizedBox(height: 18),
          if (term.isEmpty)
            const _MutedText('Empieza a escribir para buscar en tu StudyFlow.')
          else ...[
            Text('Tareas', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (matchingTasks.isEmpty)
              const _MutedText('Sin tareas encontradas')
            else
              ...matchingTasks.map((task) => ListTile(
                    leading:
                        const Icon(Icons.task_alt, color: AppColors.secondary),
                    title: Text(task.title),
                    subtitle: Text(task.dueDate == null
                        ? task.category ?? 'Sin fecha'
                        : task.dueDate!.toIso8601String().substring(0, 10)),
                    onTap: () => context.go('/tasks/${task.id}'),
                  )),
            const SizedBox(height: 16),
            Text('Rutinas', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (matchingRoutines.isEmpty)
              const _MutedText('Sin rutinas encontradas')
            else
              ...matchingRoutines.map((routine) => ListTile(
                    leading: const Icon(Icons.auto_awesome,
                        color: AppColors.secondary),
                    title: Text(routine.name),
                    subtitle: Text(routine.type.value),
                    onTap: () => context.go('/routines'),
                  )),
          ],
        ],
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  final String text;

  const _MutedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppColors.textMuted),
    );
  }
}
