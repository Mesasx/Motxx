import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppSettings {
  final ThemeMode themeMode;
  final Locale locale;
  final String ollamaUrl;
  final String ollamaModel;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('es'),
    this.ollamaUrl = 'http://localhost:11434',
    this.ollamaModel = 'llama3.2',
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? ollamaUrl,
    String? ollamaModel,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      ollamaUrl: ollamaUrl ?? this.ollamaUrl,
      ollamaModel: ollamaModel ?? this.ollamaModel,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  void _load() {
    final box = Hive.box('settings');
    final theme = box.get('themeMode', defaultValue: 'system') as String;
    final lang = box.get('locale', defaultValue: 'es') as String;
    final url =
        box.get('ollamaUrl', defaultValue: 'http://localhost:11434') as String;
    final model = box.get('ollamaModel', defaultValue: 'llama3.2') as String;

    state = AppSettings(
      themeMode: _themeFromString(theme),
      locale: Locale(lang),
      ollamaUrl: url,
      ollamaModel: model,
    );
  }

  ThemeMode _themeFromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await Hive.box('settings').put('themeMode', _themeToString(mode));
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await Hive.box('settings').put('locale', locale.languageCode);
  }

  Future<void> setOllama({String? url, String? model}) async {
    state = state.copyWith(ollamaUrl: url, ollamaModel: model);
    final box = Hive.box('settings');
    if (url != null) await box.put('ollamaUrl', url);
    if (model != null) await box.put('ollamaModel', model);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
    (ref) => SettingsNotifier());
