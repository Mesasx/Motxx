import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

class AIResponse {
  final String text;
  final bool ok;
  final String provider;
  final String? error;

  const AIResponse({
    required this.text,
    required this.ok,
    required this.provider,
    this.error,
  });
}

class AIService {
  AIService._();
  static final AIService instance = AIService._();

  String get _ollamaBaseUrl => dotenv.env['OLLAMA_URL']?.isNotEmpty == true
      ? dotenv.env['OLLAMA_URL']!
      : AppConstants.defaultOllamaUrl;

  String get _ollamaModel => dotenv.env['OLLAMA_MODEL']?.isNotEmpty == true
      ? dotenv.env['OLLAMA_MODEL']!
      : AppConstants.defaultOllamaModel;

  String get _anthropicApiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  Future<bool> isOllamaAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$_ollamaBaseUrl/api/tags'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AIResponse> ask({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = false,
  }) async {
    if (await isOllamaAvailable()) {
      return _askOllama(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        jsonMode: jsonMode,
      );
    }

    return _askAnthropic(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      jsonMode: jsonMode,
    );
  }

  Stream<String> stream({
    required String systemPrompt,
    required String userPrompt,
    bool jsonMode = false,
  }) async* {
    if (await isOllamaAvailable()) {
      yield* _streamOllama(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        jsonMode: jsonMode,
      );
      return;
    }

    yield* _streamAnthropic(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      jsonMode: jsonMode,
    );
  }

  Future<AIResponse> _askOllama({
    required String systemPrompt,
    required String userPrompt,
    required bool jsonMode,
  }) async {
    try {
      final body = <String, dynamic>{
        'model': _ollamaModel,
        'system': systemPrompt,
        'prompt': _userPrompt(userPrompt, jsonMode),
        'stream': false,
      };
      if (jsonMode) body['format'] = 'json';

      final response = await http
          .post(
            Uri.parse('$_ollamaBaseUrl/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        return AIResponse(
          text: '',
          ok: false,
          provider: 'ollama',
          error: 'HTTP ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AIResponse(
        text: (data['response'] ?? '').toString(),
        ok: true,
        provider: 'ollama',
      );
    } catch (error) {
      return AIResponse(
        text: '',
        ok: false,
        provider: 'ollama',
        error: error.toString(),
      );
    }
  }

  Future<AIResponse> _askAnthropic({
    required String systemPrompt,
    required String userPrompt,
    required bool jsonMode,
  }) async {
    if (_anthropicApiKey.isEmpty) {
      return const AIResponse(
        text: '',
        ok: false,
        provider: 'anthropic',
        error: 'No Anthropic API key',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.anthropicEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': _anthropicApiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': AppConstants.anthropicModel,
              'max_tokens': jsonMode ? 4096 : 2048,
              'system': systemPrompt,
              'messages': [
                {
                  'role': 'user',
                  'content': _userPrompt(userPrompt, jsonMode),
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        return AIResponse(
          text: '',
          ok: false,
          provider: 'anthropic',
          error: 'HTTP ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>?;
      final text = content
              ?.whereType<Map<String, dynamic>>()
              .where((chunk) => chunk['type'] == 'text')
              .map((chunk) => chunk['text'] as String? ?? '')
              .join('\n') ??
          '';
      return AIResponse(text: text, ok: true, provider: 'anthropic');
    } catch (error) {
      return AIResponse(
        text: '',
        ok: false,
        provider: 'anthropic',
        error: error.toString(),
      );
    }
  }

  Stream<String> _streamOllama({
    required String systemPrompt,
    required String userPrompt,
    required bool jsonMode,
  }) async* {
    final client = http.Client();
    try {
      final request =
          http.Request('POST', Uri.parse('$_ollamaBaseUrl/api/generate'))
            ..headers['Content-Type'] = 'application/json'
            ..body = jsonEncode({
              'model': _ollamaModel,
              'system': systemPrompt,
              'prompt': _userPrompt(userPrompt, jsonMode),
              'stream': true,
              if (jsonMode) 'format': 'json',
            });

      final response =
          await client.send(request).timeout(const Duration(seconds: 120));
      if (response.statusCode != 200) {
        yield 'No se pudo conectar con Ollama (HTTP ${response.statusCode}).';
        return;
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        final data = jsonDecode(line) as Map<String, dynamic>;
        final text = data['response']?.toString() ?? '';
        if (text.isNotEmpty) yield text;
        if (data['done'] == true) break;
      }
    } catch (error) {
      yield 'No se pudo generar la respuesta local: $error';
    } finally {
      client.close();
    }
  }

  Stream<String> _streamAnthropic({
    required String systemPrompt,
    required String userPrompt,
    required bool jsonMode,
  }) async* {
    if (_anthropicApiKey.isEmpty) {
      yield 'No hay clave de Anthropic configurada y Ollama no está disponible.';
      return;
    }

    final client = http.Client();
    try {
      final request =
          http.Request('POST', Uri.parse(AppConstants.anthropicEndpoint))
            ..headers.addAll({
              'Content-Type': 'application/json',
              'x-api-key': _anthropicApiKey,
              'anthropic-version': '2023-06-01',
            })
            ..body = jsonEncode({
              'model': AppConstants.anthropicModel,
              'max_tokens': jsonMode ? 4096 : 2048,
              'system': systemPrompt,
              'stream': true,
              'messages': [
                {
                  'role': 'user',
                  'content': _userPrompt(userPrompt, jsonMode),
                }
              ],
            });

      final response =
          await client.send(request).timeout(const Duration(seconds: 120));
      if (response.statusCode != 200) {
        yield 'No se pudo conectar con Anthropic (HTTP ${response.statusCode}).';
        return;
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final payload = line.substring(6).trim();
        if (payload == '[DONE]') break;
        final data = jsonDecode(payload) as Map<String, dynamic>;
        if (data['type'] != 'content_block_delta') continue;
        final delta = data['delta'] as Map<String, dynamic>? ?? const {};
        final text = delta['text']?.toString() ?? '';
        if (text.isNotEmpty) yield text;
      }
    } catch (error) {
      yield 'No se pudo generar la respuesta remota: $error';
    } finally {
      client.close();
    }
  }

  String _userPrompt(String prompt, bool jsonMode) {
    if (!jsonMode) return prompt;
    return '$prompt\n\nResponde SOLO con un JSON válido, sin texto adicional.';
  }
}
