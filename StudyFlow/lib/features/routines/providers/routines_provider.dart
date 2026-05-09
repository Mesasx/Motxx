import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../shared/models/routine_model.dart';

class RoutinesNotifier extends StateNotifier<AsyncValue<List<RoutineModel>>> {
  RoutinesNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    try {
      if (!SupabaseService.instance.isConfigured ||
          !SupabaseService.instance.isLoggedIn) {
        state = const AsyncValue.data([]);
        return;
      }
      final res = await SupabaseService.instance.client
          .from('routines')
          .select()
          .order('created_at', ascending: false);
      final list = (res as List)
          .map((m) => RoutineModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<RoutineModel?> create({
    required RoutineType type,
    required String name,
    required Map<String, dynamic> config,
  }) async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return null;
    final res = await SupabaseService.instance.client
        .from('routines')
        .insert({
          'user_id': user.id,
          'type': type.value,
          'name': name,
          'config': config,
          'active': true,
        })
        .select()
        .single();
    await fetch();
    return RoutineModel.fromMap(Map<String, dynamic>.from(res));
  }

  Future<void> setActive(String id, bool active) async {
    await SupabaseService.instance.client
        .from('routines')
        .update({'active': active}).eq('id', id);
    await fetch();
  }

  Future<void> delete(String id) async {
    await SupabaseService.instance.client
        .from('routines')
        .delete()
        .eq('id', id);
    await fetch();
  }
}

final routinesProvider =
    StateNotifierProvider<RoutinesNotifier, AsyncValue<List<RoutineModel>>>(
        (ref) => RoutinesNotifier());
