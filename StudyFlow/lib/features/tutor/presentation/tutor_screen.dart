import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/ai_context_manager.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/routine_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../routines/providers/routines_provider.dart';

class TutorScreen extends ConsumerWidget {
  const TutorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tutor IA')),
      body: routines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (items) {
          final subjects = _subjectsFromRoutines(items);
          if (subjects.isEmpty) {
            return EmptyState(
              icon: Icons.school_outlined,
              title: 'Sin asignaturas activas',
              subtitle:
                  'Crea una rutina de exámenes para abrir un tutor con tus apuntes.',
              action: FilledButton.icon(
                onPressed: () => context.go('/routines/new'),
                icon: const Icon(Icons.add),
                label: const Text('Crear rutina'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Elige asignatura',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'El tutor usa el mapa de contenidos y los apuntes de tus rutinas activas.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ...subjects.map((subject) {
                final topics =
                    subject.contentMap['topics'] as List? ?? const [];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    tileColor: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    leading: const Icon(Icons.menu_book_outlined,
                        color: AppColors.secondary),
                    title: Text(subject.name),
                    subtitle: Text(
                      topics.isEmpty
                          ? 'Sin mapa de contenido todavía'
                          : '${topics.length} temas analizados',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(
                      '/tutor/${Uri.encodeComponent(subject.name)}',
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  List<_TutorSubject> _subjectsFromRoutines(List<RoutineModel> routines) {
    final byName = <String, _TutorSubject>{};
    for (final routine in routines.where((routine) => routine.active)) {
      final subjects = routine.config['subjects'] as List? ?? const [];
      for (final raw in subjects) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final name = map['name']?.toString().trim();
        if (name == null || name.isEmpty || byName.containsKey(name)) continue;
        byName[name] = _TutorSubject(
          name: name,
          routineId: routine.id,
          contentMap:
              Map<String, dynamic>.from(map['content_map'] as Map? ?? const {}),
        );
      }
    }
    return byName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}

class TutorChatScreen extends ConsumerStatefulWidget {
  final String subject;

  const TutorChatScreen({super.key, required this.subject});

  @override
  ConsumerState<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends ConsumerState<TutorChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_TutorMessage> _messages = [];
  bool _loading = true;
  bool _streaming = false;
  String? _conversationId;
  _TutorSubject? _subject;
  List<String> _noteChunks = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      _subject = _findSubject();
      _noteChunks = await _loadNoteChunks();
      await _loadConversation();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _TutorSubject? _findSubject() {
    final routines =
        ref.read(routinesProvider).valueOrNull ?? const <RoutineModel>[];
    for (final routine in routines.where((routine) => routine.active)) {
      final subjects = routine.config['subjects'] as List? ?? const [];
      for (final raw in subjects) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final name = map['name']?.toString().trim();
        if (name != widget.subject) continue;
        return _TutorSubject(
          name: widget.subject,
          routineId: routine.id,
          contentMap:
              Map<String, dynamic>.from(map['content_map'] as Map? ?? const {}),
        );
      }
    }
    return null;
  }

  Future<List<String>> _loadNoteChunks() async {
    if (!SupabaseService.instance.isConfigured ||
        !SupabaseService.instance.isLoggedIn ||
        _subject == null) {
      return const [];
    }

    try {
      final response = await SupabaseService.instance.client
          .from('notes_files')
          .select('file_url, extracted_text, subject')
          .eq('routine_id', _subject!.routineId);

      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .where((row) {
        final subject = row['subject']?.toString();
        return subject == null || subject.isEmpty || subject == widget.subject;
      });

      final chunks = <String>[];
      for (final row in rows) {
        final text = row['extracted_text']?.toString().trim();
        if (text == null || text.isEmpty) continue;
        chunks.addAll(_chunkText(text));
      }
      return chunks;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _loadConversation() async {
    if (!SupabaseService.instance.isConfigured ||
        !SupabaseService.instance.isLoggedIn) {
      return;
    }

    try {
      final response = await SupabaseService.instance.client
          .from('tutor_conversations')
          .select()
          .eq('subject', widget.subject)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return;
      final row = Map<String, dynamic>.from(response);
      _conversationId = row['id']?.toString();
      final messages = row['messages'] as List? ?? const [];
      _messages
        ..clear()
        ..addAll(messages.map((message) {
          final map = Map<String, dynamic>.from(message as Map);
          return _TutorMessage(
            role: map['role']?.toString() == 'assistant'
                ? _MessageRole.assistant
                : _MessageRole.user,
            content: map['content']?.toString() ?? '',
          );
        }));
    } catch (_) {}
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _streaming) return;

    setState(() {
      _controller.clear();
      _messages.add(_TutorMessage(role: _MessageRole.user, content: question));
      _messages
          .add(const _TutorMessage(role: _MessageRole.assistant, content: ''));
      _streaming = true;
    });
    _scrollToBottom();

    final assistantIndex = _messages.length - 1;
    try {
      final notes = _buildRelevantContext(question);
      final prompt = await AIContextManager.instance.buildTutorPrompt(
        widget.subject,
        notes,
        question,
      );
      final systemPrompt = await AIContextManager.instance
          .buildSystemPrompt(subject: widget.subject);

      await for (final chunk in AIService.instance.stream(
        systemPrompt: systemPrompt,
        userPrompt: prompt,
      )) {
        for (final piece in _wordPieces(chunk)) {
          if (!mounted) return;
          setState(() {
            final current = _messages[assistantIndex];
            _messages[assistantIndex] = current.copyWith(
              content: current.content + piece,
            );
          });
          _scrollToBottom();
          await Future<void>.delayed(const Duration(milliseconds: 12));
        }
      }
      await _saveConversation();
    } finally {
      if (mounted) setState(() => _streaming = false);
    }
  }

  String _buildRelevantContext(String question) {
    final parts = <String>[];
    final contentMap = _subject?.contentMap ?? const <String, dynamic>{};
    if (contentMap.isNotEmpty) {
      parts
        ..add('=== MAPA DE CONTENIDO ===')
        ..add(const JsonEncoder.withIndent('  ').convert(contentMap));
    }

    final chunks = _bestChunks(question, _noteChunks, maxChunks: 4);
    if (chunks.isNotEmpty) {
      parts
        ..add('=== FRAGMENTOS DE APUNTES MÁS RELEVANTES ===')
        ..addAll(chunks.asMap().entries.map(
              (entry) => '--- Fragmento ${entry.key + 1} ---\n${entry.value}',
            ));
    }

    if (parts.isEmpty) {
      return 'No hay apuntes recuperados. Responde con el contexto del perfil y pide al usuario que suba apuntes si necesitas precisión.';
    }
    return parts.join('\n\n');
  }

  List<String> _bestChunks(String question, List<String> chunks,
      {required int maxChunks}) {
    final terms = question
        .toLowerCase()
        .split(RegExp(r'[^a-záéíóúüñ0-9]+'))
        .where((term) => term.length > 3)
        .toSet();
    if (terms.isEmpty) return chunks.take(maxChunks).toList();

    final scored = chunks
        .map((chunk) {
          final lower = chunk.toLowerCase();
          final score = terms.where(lower.contains).length;
          return MapEntry(chunk, score);
        })
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (scored.isEmpty) return chunks.take(maxChunks).toList();
    return scored.take(maxChunks).map((entry) => entry.key).toList();
  }

  List<String> _chunkText(String text) {
    const chunkSize = 2200;
    final chunks = <String>[];
    for (var start = 0; start < text.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, text.length).toInt();
      chunks.add(text.substring(start, end));
    }
    return chunks;
  }

  List<String> _wordPieces(String chunk) {
    final matches = RegExp(r'\S+\s*').allMatches(chunk);
    final pieces = matches.map((match) => match.group(0) ?? '').toList();
    return pieces.isEmpty ? [chunk] : pieces;
  }

  Future<void> _saveConversation() async {
    if (!SupabaseService.instance.isConfigured ||
        !SupabaseService.instance.isLoggedIn) {
      return;
    }
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    final payload = {
      'user_id': user.id,
      'subject': widget.subject,
      'messages': _messages.map((message) => message.toMap()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      if (_conversationId == null) {
        final response = await SupabaseService.instance.client
            .from('tutor_conversations')
            .insert(payload)
            .select('id')
            .single();
        _conversationId = (response as Map)['id']?.toString();
      } else {
        await SupabaseService.instance.client
            .from('tutor_conversations')
            .update(payload)
            .eq('id', _conversationId!);
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/tutor'),
        ),
      ),
      body: LoadingOverlay(
        loading: _loading,
        child: Column(
          children: [
            if (_subject?.contentMap.isNotEmpty == true)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                color: AppColors.secondary.withValues(alpha: 0.08),
                child: Text(
                  'Contexto: content_map + ${_noteChunks.length} fragmentos de apuntes',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.secondary),
                ),
              ),
            Expanded(
              child: _messages.isEmpty
                  ? const EmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'Pregunta como en tutoría',
                      subtitle:
                          'Pide explicaciones, ejemplos, preguntas tipo examen o corrección de respuestas.',
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _messages.length,
                      itemBuilder: (_, index) {
                        final message = _messages[index];
                        return _MessageBubble(message: message);
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText:
                              'Pregunta una duda, pide ejemplo o examen...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _streaming ? null : _send,
                      icon: _streaming
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _TutorMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _MessageRole.user;
    final theme = Theme.of(context);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.secondary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: isUser ? null : Border.all(color: AppColors.borderSubtle),
        ),
        child: SelectableText(
          message.content.isEmpty ? '...' : message.content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isUser ? Colors.white : AppColors.textBody,
          ),
        ),
      ),
    );
  }
}

class _TutorSubject {
  final String name;
  final String routineId;
  final Map<String, dynamic> contentMap;

  const _TutorSubject({
    required this.name,
    required this.routineId,
    required this.contentMap,
  });
}

enum _MessageRole { user, assistant }

class _TutorMessage {
  final _MessageRole role;
  final String content;

  const _TutorMessage({required this.role, required this.content});

  _TutorMessage copyWith({String? content}) {
    return _TutorMessage(role: role, content: content ?? this.content);
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role == _MessageRole.assistant ? 'assistant' : 'user',
      'content': content,
    };
  }
}
