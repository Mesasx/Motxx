import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/ai_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/widgets/loading_overlay.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _testing = false;

  Future<void> _testOllama() async {
    setState(() => _testing = true);
    final ok = await AIService.instance.isOllamaAvailable();
    if (!mounted) return;
    setState(() => _testing = false);
    showSnack(
        context, ok ? 'Ollama OK ✓' : 'Ollama no disponible. ¿Está en marcha?',
        error: !ok);
  }

  Future<void> _exportData() async {
    if (!SupabaseService.instance.isLoggedIn) return;
    try {
      final tasks =
          await SupabaseService.instance.client.from('tasks').select();
      final routines =
          await SupabaseService.instance.client.from('routines').select();
      final blocks = await SupabaseService.instance.client
          .from('schedule_blocks')
          .select();
      final json = const JsonEncoder.withIndent('  ').convert({
        'tasks': tasks,
        'routines': routines,
        'schedule_blocks': blocks,
      });
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Datos exportados'),
          content: SingleChildScrollView(child: SelectableText(json)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'))
          ],
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Error: $e', error: true);
    }
  }

  Future<void> _exportIcs() async {
    if (!SupabaseService.instance.isLoggedIn) return;
    try {
      final tasks =
          await SupabaseService.instance.client.from('tasks').select();
      final blocks = await SupabaseService.instance.client
          .from('schedule_blocks')
          .select();
      final ics = _buildIcs(tasks as List, blocks as List);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Calendario .ics'),
          content: SingleChildScrollView(child: SelectableText(ics)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Error: $e', error: true);
    }
  }

  String _buildIcs(List tasks, List blocks) {
    String esc(Object? value) => (value?.toString() ?? '')
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;')
        .replaceAll('\n', '\\n');
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';
    String dateTime(DateTime value) =>
        '${date(value)}T${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}00';

    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//StudyFlow//StudyFlow v2//ES');

    for (final raw in tasks) {
      final task = Map<String, dynamic>.from(raw as Map);
      final due = DateTime.tryParse(task['due_date']?.toString() ?? '');
      if (due == null) continue;
      final time = task['due_time']?.toString();
      final start = time == null
          ? due
          : DateTime(
              due.year,
              due.month,
              due.day,
              int.tryParse(time.substring(0, 2)) ?? 9,
              int.tryParse(time.substring(3, 5)) ?? 0,
            );
      final end = start.add(const Duration(minutes: 45));
      buffer
        ..writeln('BEGIN:VEVENT')
        ..writeln('UID:${esc(task['id'])}@studyflow')
        ..writeln('SUMMARY:${esc(task['title'])}')
        ..writeln('DESCRIPTION:${esc(task['description'])}')
        ..writeln(time == null
            ? 'DTSTART;VALUE=DATE:${date(start)}'
            : 'DTSTART:${dateTime(start)}')
        ..writeln(time == null
            ? 'DTEND;VALUE=DATE:${date(start.add(const Duration(days: 1)))}'
            : 'DTEND:${dateTime(end)}')
        ..writeln('END:VEVENT');
    }

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    for (final raw in blocks) {
      final block = Map<String, dynamic>.from(raw as Map);
      final weekday = (block['day_of_week'] as num?)?.toInt() ?? 1;
      final day = monday.add(Duration(days: weekday - 1));
      DateTime at(String key) {
        final value = block[key].toString();
        return DateTime(
          day.year,
          day.month,
          day.day,
          int.tryParse(value.substring(0, 2)) ?? 9,
          int.tryParse(value.substring(3, 5)) ?? 0,
        );
      }

      buffer
        ..writeln('BEGIN:VEVENT')
        ..writeln('UID:${esc(block['id'])}@studyflow')
        ..writeln('SUMMARY:${esc(block['subject'])}')
        ..writeln('LOCATION:${esc(block['location'])}')
        ..writeln('DTSTART:${dateTime(at('start_time'))}')
        ..writeln('DTEND:${dateTime(at('end_time'))}')
        ..writeln('RRULE:FREQ=WEEKLY')
        ..writeln('END:VEVENT');
    }
    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
            'Esta acción no se puede deshacer. Se borrarán todas tus tareas, rutinas y horario.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) return;
      await SupabaseService.instance.client
          .from('tasks')
          .delete()
          .eq('user_id', user.id);
      await SupabaseService.instance.client
          .from('routines')
          .delete()
          .eq('user_id', user.id);
      await SupabaseService.instance.client
          .from('schedule_blocks')
          .delete()
          .eq('user_id', user.id);
      await SupabaseService.instance.signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) showSnack(context, 'Error: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: LoadingOverlay(
        loading: _testing,
        child: ListView(
          children: [
            _Section(title: 'Cuenta', children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(user?.email ?? 'No has iniciado sesión'),
                trailing: user != null
                    ? TextButton(
                        onPressed: () async {
                          await SupabaseService.instance.signOut();
                          if (context.mounted) context.go('/login');
                        },
                        child: const Text('Cerrar sesión'),
                      )
                    : TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Iniciar sesión'),
                      ),
              ),
            ]),
            _Section(title: 'Tema', children: [
              RadioGroup<ThemeMode>(
                groupValue: settings.themeMode,
                onChanged: (v) {
                  if (v != null) {
                    ref.read(settingsProvider.notifier).setTheme(v);
                  }
                },
                child: const Column(
                  children: [
                    ListTile(
                      leading: Radio<ThemeMode>(value: ThemeMode.system),
                      title: Text('Sistema'),
                    ),
                    ListTile(
                      leading: Radio<ThemeMode>(value: ThemeMode.light),
                      title: Text('Claro'),
                    ),
                    ListTile(
                      leading: Radio<ThemeMode>(value: ThemeMode.dark),
                      title: Text('Oscuro'),
                    ),
                  ],
                ),
              ),
            ]),
            _Section(title: 'Idioma', children: [
              RadioGroup<String>(
                groupValue: settings.locale.languageCode,
                onChanged: (v) {
                  if (v != null) {
                    ref.read(settingsProvider.notifier).setLocale(Locale(v));
                  }
                },
                child: const Column(
                  children: [
                    ListTile(
                      leading: Radio<String>(value: 'es'),
                      title: Text('Español'),
                    ),
                    ListTile(
                      leading: Radio<String>(value: 'en'),
                      title: Text('English'),
                    ),
                  ],
                ),
              ),
            ]),
            _Section(title: 'Ollama (IA local)', children: [
              ListTile(
                title: const Text('URL'),
                subtitle: Text(settings.ollamaUrl),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final c = TextEditingController(text: settings.ollamaUrl);
                  final v = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('URL de Ollama'),
                      content: TextField(controller: c),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, c.text),
                            child: const Text('OK')),
                      ],
                    ),
                  );
                  if (v != null && v.isNotEmpty) {
                    ref.read(settingsProvider.notifier).setOllama(url: v);
                  }
                },
              ),
              ListTile(
                title: const Text('Modelo'),
                subtitle: Text(settings.ollamaModel),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final c = TextEditingController(text: settings.ollamaModel);
                  final v = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Modelo Ollama'),
                      content: TextField(controller: c),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, c.text),
                            child: const Text('OK')),
                      ],
                    ),
                  );
                  if (v != null && v.isNotEmpty) {
                    ref.read(settingsProvider.notifier).setOllama(model: v);
                  }
                },
              ),
              ListTile(
                title: const Text('Probar conexión'),
                trailing: const Icon(Icons.sync),
                onTap: _testOllama,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Si no tienes Ollama instalado, ve a https://ollama.ai e instala el modelo: ollama pull llama3.2',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ]),
            _Section(title: 'Datos', children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Exportar datos (JSON)'),
                onTap: _exportData,
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Exportar calendario (.ics)'),
                onTap: _exportIcs,
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Eliminar cuenta',
                    style: TextStyle(color: Colors.red)),
                onTap: _confirmDelete,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
