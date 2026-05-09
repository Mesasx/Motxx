import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../models/user_profile_context_model.dart';
import '../models/user_profile_model.dart';

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfileModel?>> {
  ProfileNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final box = Hive.box('settings');
      final cached = box.get('user_profile') as String?;
      if (cached != null) {
        final map = Map<String, dynamic>.from(jsonDecode(cached) as Map);
        state = AsyncValue.data(UserProfileModel.fromMap(map));
      }

      if (SupabaseService.instance.isConfigured &&
          SupabaseService.instance.isLoggedIn) {
        final userId = SupabaseService.instance.currentUser!.id;
        final res = await SupabaseService.instance.client
            .from('user_profile_context')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (res != null) {
          final profile = _fromContext(
            UserProfileContextModel.fromMap(Map<String, dynamic>.from(res)),
          );
          state = AsyncValue.data(profile);
          await _cacheLocally(profile);
        } else if (cached == null) {
          state = const AsyncValue.data(null);
        }
      } else if (cached == null) {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save(UserProfileModel profile) async {
    try {
      await _cacheLocally(profile);
      state = AsyncValue.data(profile);

      if (SupabaseService.instance.isConfigured &&
          SupabaseService.instance.isLoggedIn) {
        final user = SupabaseService.instance.currentUser!;
        await SupabaseService.instance.client.from('profiles').upsert({
          'id': user.id,
          'email': user.email ?? '',
          'display_name': profile.displayName,
          'settings': {'legacy_profile': profile.toInsertMap()},
        }, onConflict: 'id');
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _cacheLocally(UserProfileModel profile) async {
    final box = Hive.box('settings');
    await box.put('user_profile', profile.toJsonString());
  }

  void clear() {
    Hive.box('settings').delete('user_profile');
    state = const AsyncValue.data(null);
  }

  UserProfileModel _fromContext(UserProfileContextModel contextModel) {
    final context = contextModel.context;
    final user = SupabaseService.instance.currentUser;
    final displayName = user?.userMetadata?['display_name']?.toString() ??
        user?.email?.split('@').first ??
        'StudyFlow';
    final subjects =
        List<String>.from(context['subjects'] as List? ?? const []);
    final preferredTime = context['concentration_window']?.toString();
    final weekdayHours =
        (context['weekday_hours_per_day'] as num?)?.toDouble() ?? 2;
    final weekendHours =
        (context['weekend_hours_per_day'] as num?)?.toDouble() ?? 1;
    final professionalHours =
        (context['professional_hours_per_day'] as num?)?.toDouble();

    final weeklyHours = contextModel.profileType == ProfileType.professional
        ? ((professionalHours ?? weekdayHours) * 5).round()
        : (weekdayHours * 5 + weekendHours * 2).round();

    return UserProfileModel(
      userId: contextModel.userId,
      displayName: displayName,
      institution: null,
      level: context['education_level']?.toString() ?? 'grado',
      degree:
          context['studies']?.toString() ?? context['sector_role']?.toString(),
      yearOfStudy: (context['current_year'] as num?)?.toInt(),
      subjects: subjects,
      primaryGoal: context['primary_goal']?.toString() ?? 'aprobar',
      studyStyle: context['study_style']?.toString() ?? 'mixto',
      weeklyHoursAvailable: weeklyHours.clamp(1, 80).toInt(),
      preferredTimes: preferredTime == null ? const ['tarde'] : [preferredTime],
      weakTopics: const [],
      extraContext: context['professional_goals']?.toString(),
      createdAt: contextModel.updatedAt,
    );
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfileModel?>>(
  (ref) => ProfileNotifier(),
);

/// True only once the profile has loaded AND a profile exists.
final hasProfileProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider).maybeWhen(
        data: (p) => p != null,
        orElse: () => false,
      );
});

/// True while the profile is still being fetched (prevents premature redirect).
final profileLoadingProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider).isLoading;
});
