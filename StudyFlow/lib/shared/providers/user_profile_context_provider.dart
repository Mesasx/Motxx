import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../models/user_profile_context_model.dart';

class UserProfileContextNotifier
    extends StateNotifier<AsyncValue<UserProfileContextModel?>> {
  UserProfileContextNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  static const _cacheKey = 'user_profile_context';

  Future<void> load() async {
    try {
      final cached = _readCache();
      if (cached != null) {
        state = AsyncValue.data(cached);
      }

      if (SupabaseService.instance.isConfigured &&
          SupabaseService.instance.isLoggedIn) {
        final userId = SupabaseService.instance.currentUser!.id;
        final response = await SupabaseService.instance.client
            .from('user_profile_context')
            .select()
            .eq('user_id', userId)
            .maybeSingle();

        if (response != null) {
          final context = UserProfileContextModel.fromMap(
            Map<String, dynamic>.from(response),
          );
          await _cache(context);
          state = AsyncValue.data(context);
        } else if (cached == null) {
          state = const AsyncValue.data(null);
        }
      } else if (cached == null) {
        state = const AsyncValue.data(null);
      }
    } catch (error, stackTrace) {
      final cached = _readCache();
      if (cached != null) {
        state = AsyncValue.data(cached);
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> save(UserProfileContextModel context) async {
    try {
      await _cache(context);
      state = AsyncValue.data(context);

      if (SupabaseService.instance.isConfigured &&
          SupabaseService.instance.isLoggedIn) {
        await SupabaseService.instance.client
            .from('user_profile_context')
            .upsert(context.toUpsertMap(), onConflict: 'user_id');
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  UserProfileContextModel? _readCache() {
    final raw = Hive.box('settings').get(_cacheKey) as String?;
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return UserProfileContextModel.fromMap(map);
  }

  Future<void> _cache(UserProfileContextModel context) async {
    await Hive.box('settings').put(_cacheKey, context.toJsonString());
  }

  Future<void> clear() async {
    await Hive.box('settings').delete(_cacheKey);
    state = const AsyncValue.data(null);
  }
}

final userProfileContextProvider = StateNotifierProvider<
    UserProfileContextNotifier, AsyncValue<UserProfileContextModel?>>(
  (ref) => UserProfileContextNotifier(),
);

final onboardingCompletedProvider = Provider<bool>((ref) {
  return ref.watch(userProfileContextProvider).maybeWhen(
        data: (context) => context?.onboardingCompleted ?? false,
        orElse: () => false,
      );
});

final onboardingLoadingProvider = Provider<bool>((ref) {
  return ref.watch(userProfileContextProvider).isLoading;
});
