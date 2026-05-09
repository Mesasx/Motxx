import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../shared/models/schedule_block_model.dart';

class ScheduleNotifier
    extends StateNotifier<AsyncValue<List<ScheduleBlockModel>>> {
  ScheduleNotifier() : super(const AsyncValue.loading()) {
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
          .from('schedule_blocks')
          .select()
          .order('day_of_week')
          .order('start_time');
      final list = (res as List)
          .map((m) => ScheduleBlockModel.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(ScheduleBlockModel block) async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;
    await SupabaseService.instance.client
        .from('schedule_blocks')
        .insert(block.toInsertMap());
    await fetch();
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await SupabaseService.instance.client
        .from('schedule_blocks')
        .update(patch)
        .eq('id', id);
    await fetch();
  }

  Future<void> delete(String id) async {
    await SupabaseService.instance.client
        .from('schedule_blocks')
        .delete()
        .eq('id', id);
    await fetch();
  }
}

final scheduleProvider = StateNotifierProvider<ScheduleNotifier,
    AsyncValue<List<ScheduleBlockModel>>>((ref) => ScheduleNotifier());
