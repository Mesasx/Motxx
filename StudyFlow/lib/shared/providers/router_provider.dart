import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/today/presentation/today_screen.dart';
import '../../features/today/presentation/task_detail_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/search/presentation/global_search_screen.dart';
import '../../features/routines/presentation/routines_screen.dart';
import '../../features/routines/presentation/routine_wizard_screen.dart';
import '../../features/tutor/presentation/tutor_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../widgets/app_shell.dart';
import 'auth_provider.dart';
import 'user_profile_context_provider.dart';
import '../../core/services/supabase_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final loggedIn = ref.watch(isLoggedInProvider);
  final supaConfigured = SupabaseService.instance.isConfigured;
  final onboardingCompleted = ref.watch(onboardingCompletedProvider);
  final onboardingLoading = ref.watch(onboardingLoadingProvider);

  return GoRouter(
    initialLocation: '/today',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggingIn = loc == '/login' || loc == '/signup';
      final onboarding = loc == '/onboarding';

      if (!supaConfigured) {
        // No auth gate without Supabase – skip onboarding redirect too
        return null;
      }

      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/today';

      // Only redirect once the context state is known.
      if (loggedIn &&
          !onboardingLoading &&
          !onboardingCompleted &&
          !onboarding) {
        return '/onboarding';
      }
      if (loggedIn && onboardingCompleted && onboarding) return '/today';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
          GoRoute(
            path: '/tasks/:taskId',
            builder: (_, state) =>
                TaskDetailScreen(taskId: state.pathParameters['taskId']!),
          ),
          GoRoute(
            path: '/focus/:taskId',
            builder: (_, state) =>
                FocusModeScreen(taskId: state.pathParameters['taskId']!),
          ),
          GoRoute(
              path: '/schedule', builder: (_, __) => const ScheduleScreen()),
          GoRoute(
              path: '/search', builder: (_, __) => const GlobalSearchScreen()),
          GoRoute(
            path: '/tutor',
            builder: (_, __) => const TutorScreen(),
            routes: [
              GoRoute(
                path: ':subject',
                builder: (_, state) => TutorChatScreen(
                  subject:
                      Uri.decodeComponent(state.pathParameters['subject']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/routines',
            builder: (_, __) => const RoutinesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const RoutineWizardScreen(),
              ),
            ],
          ),
          GoRoute(
              path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
    errorBuilder: (_, __) =>
        const Scaffold(body: Center(child: Text('Ruta no encontrada'))),
  );
});
