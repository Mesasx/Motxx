class AppConstants {
  AppConstants._();

  static const String appName = 'StudyFlow';
  static const String defaultOllamaUrl = 'http://localhost:11434';
  static const String defaultOllamaModel = 'llama3.2';
  static const String anthropicEndpoint =
      'https://api.anthropic.com/v1/messages';
  static const String anthropicModel = 'claude-sonnet-4-20250514';

  static const Duration animDuration = Duration(milliseconds: 220);

  static const List<String> defaultCategories = [
    'Estudio',
    'Trabajo',
    'Personal',
    'Deporte',
    'Otros',
  ];
}
