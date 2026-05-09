import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/core/ai/ai_context_manager.dart';
import 'package:studyflow/shared/models/user_profile_context_model.dart';

void main() {
  group('AIContextManager', () {
    test('builds student professor persona from onboarding context', () {
      final context = UserProfileContextModel(
        userId: 'user-1',
        profileType: ProfileType.student,
        context: const {
          'education_level': 'grado',
          'studies': 'Ingeniería Informática',
          'current_year': 2,
          'weekday_hours_per_day': 3,
          'weekend_hours_per_day': 2,
          'concentration_window': 'manana',
          'primary_goal': 'nota_alta',
          'study_style': 'repeticion_espaciada',
        },
        onboardingCompleted: true,
        updatedAt: DateTime(2026),
      );

      final prompt = AIContextManager()
          .buildSystemPromptFromContext(context, subject: 'Redes 2');

      expect(prompt, contains('profesor experto'));
      expect(prompt, contains('Ingeniería Informática'));
      expect(prompt, contains('especializado en Redes 2'));
      expect(prompt, contains('Grado'));
      expect(prompt, contains('curso 2'));
      expect(prompt, contains('3 h/día entre semana'));
      expect(prompt, contains('mañana'));
      expect(prompt, contains('sacar nota alta'));
      expect(prompt, contains('repetición espaciada'));
    });

    test('builds professional mentor persona from professional context', () {
      final context = UserProfileContextModel(
        userId: 'user-2',
        profileType: ProfileType.professional,
        context: const {
          'sector_role': 'Backend developer',
          'professional_hours_per_day': 1.5,
          'professional_goals': 'Preparar entrevistas senior',
        },
        onboardingCompleted: true,
        updatedAt: DateTime(2026),
      );

      final prompt = AIContextManager().buildSystemPromptFromContext(context);

      expect(prompt, contains('académico-profesional'));
      expect(prompt, contains('Backend developer'));
      expect(prompt, contains('1.5 h/día'));
      expect(prompt, contains('Preparar entrevistas senior'));
    });

    test('builds useful fallback without a profile context', () {
      final prompt =
          AIContextManager().buildSystemPromptFromContext(null, subject: 'SQL');

      expect(prompt, contains('profesor experto'));
      expect(prompt, contains('SQL'));
      expect(prompt, contains('poco tiempo'));
    });
  });
}
