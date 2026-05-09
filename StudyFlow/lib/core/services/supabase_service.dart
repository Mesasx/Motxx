import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  /// Será true solo si Supabase.initialize() se completó correctamente
  /// (lo marcamos desde main.dart).
  static bool _initialized = false;
  static void markInitialized() => _initialized = true;

  bool get isConfigured => _initialized;

  SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
          'Supabase no está configurado. Edita .env con tus credenciales.');
    }
    return Supabase.instance.client;
  }

  User? get currentUser =>
      _initialized ? Supabase.instance.client.auth.currentUser : null;
  Session? get currentSession =>
      _initialized ? Supabase.instance.client.auth.currentSession : null;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authChanges {
    if (!_initialized) return const Stream.empty();
    return Supabase.instance.client.auth.onAuthStateChange;
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) {
    return client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
    );
  }

  Future<void> signOut() async {
    if (!_initialized) return;
    await client.auth.signOut();
  }

  Future<String> uploadNote({
    required String userId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final path = '$userId/$fileName';
    await client.storage.from('notes').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    return client.storage.from('notes').getPublicUrl(path);
  }
}
