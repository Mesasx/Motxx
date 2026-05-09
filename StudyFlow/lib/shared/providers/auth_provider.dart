import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';

final authStateProvider = StreamProvider<AuthState?>((ref) {
  if (!SupabaseService.instance.isConfigured) {
    return const Stream<AuthState?>.empty();
  }
  return SupabaseService.instance.authChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  if (!SupabaseService.instance.isConfigured) return null;
  return SupabaseService.instance.currentUser;
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
