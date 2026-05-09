import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

class OllamaResponse {
  final String text;
  final bool ok;
  final String? error;

  OllamaResponse({required this.text, required this.ok, this.error});
}

class OllamaService {
  OllamaService._();
  static final OllamaService instance = OllamaService._();

  String get _baseUrl => dotenv.env['OLLAMA_URL']?.isNotEmpty == true
      ? dotenv.env['OLLAMA_URL']!
      : AppConstants.defaultOllamaUrl;

  String get _model => dotenv.env['OLLAMA_MODEL']?.isNotEmpty == true
      ? dotenv.env['OLLAMA_MODEL']!
      : AppConstants.defaultOllamaModel;

  Future<bool> isAvailable() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<OllamaResponse> generate({
    required String prompt,
    String? model,
    bool jsonMode = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'model': model ?? _model,
        'prompt': prompt,
        'stream': false,
      };
      if (jsonMode) body['format'] = 'json';

      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 120));

      if (res.statusCode != 200) {
        return OllamaResponse(
            text: '', ok: false, error: 'HTTP ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return OllamaResponse(
          text: (data['response'] ?? '').toString(), ok: true);
    } catch (e) {
      return OllamaResponse(text: '', ok: false, error: e.toString());
    }
  }

  /// Fallback to Anthropic API if user provided a key.
  Future<OllamaResponse> generateWithAnthropic({
    required String prompt,
    bool jsonMode = false,
  }) async {
    final apiKey = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return OllamaResponse(text: '', ok: false, error: 'No Anthropic API key');
    }
    try {
      final res = await http
          .post(
            Uri.parse(AppConstants.anthropicEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': AppConstants.anthropicModel,
              'max_tokens': 2048,
              'messages': [
                {
                  'role': 'user',
                  'content': jsonMode
                      ? '$prompt\n\nResponde SOLO con un JSON válido, sin texto adicional.'
                      : prompt,
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (res.statusCode != 200) {
        return OllamaResponse(
            text: '', ok: false, error: 'HTTP ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>?;
      final text = content
              ?.where((c) => c['type'] == 'text')
              .map((c) => c['text'] as String)
              .join('\n') ??
          '';
      return OllamaResponse(text: text, ok: true);
    } catch (e) {
      return OllamaResponse(text: '', ok: false, error: e.toString());
    }
  }
}
