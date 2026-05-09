import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_profile_context_model.dart';
import '../../../shared/models/user_profile_model.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/providers/user_profile_context_provider.dart';
import '../../../shared/widgets/loading_overlay.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _page = 0;
  bool _saving = false;

  ProfileType _profileType = ProfileType.student;
  String _educationLevel = 'grado';
  int _currentYear = 1;
  String _studyStyle = 'mixto';
  double _weekdayHours = 2;
  double _weekendHours = 2;
  String _concentrationWindow = 'tarde';
  String _primaryGoal = 'aprobar';
  double _professionalHours = 2;

  final _studiesCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _sectorRoleCtrl = TextEditingController();
  final _projectTypesCtrl = TextEditingController();
  final _professionalGoalsCtrl = TextEditingController();
  final List<String> _subjects = [];
  final List<String> _projectTypes = [];

  bool get _needsStudent =>
      _profileType == ProfileType.student || _profileType == ProfileType.mixed;

  bool get _needsProfessional =>
      _profileType == ProfileType.professional ||
      _profileType == ProfileType.mixed;

  @override
  void dispose() {
    _studiesCtrl.dispose();
    _subjectCtrl.dispose();
    _sectorRoleCtrl.dispose();
    _projectTypesCtrl.dispose();
    _professionalGoalsCtrl.dispose();
    super.dispose();
  }

  List<_OnboardingPage> get _pages {
    return [
      _OnboardingPage(
        title: '¿Qué necesitas organizar?',
        subtitle: 'La IA ajustará su criterio a tu situación real.',
        child: _ProfileTypeQuestion(
          value: _profileType,
          onChanged: (value) => setState(() {
            _profileType = value;
            _page = _page.clamp(0, _pages.length - 1).toInt();
          }),
        ),
        canContinue: true,
      ),
      if (_needsStudent) ...[
        _OnboardingPage(
          title: 'Nivel educativo',
          subtitle: 'Esto define el tono del profesor IA.',
          child: _ChoiceQuestion<String>(
            value: _educationLevel,
            options: _educationLevels,
            onChanged: (value) => setState(() => _educationLevel = value),
          ),
          canContinue: true,
        ),
        _OnboardingPage(
          title: 'Carrera o estudios concretos',
          subtitle: 'Ej: Ingeniería Informática, Medicina, Oposición a TIC.',
          child: TextField(
            controller: _studiesCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Estudios',
              hintText: 'Escribe el nombre exacto',
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          canContinue: _studiesCtrl.text.trim().isNotEmpty,
        ),
        _OnboardingPage(
          title: 'Curso actual',
          subtitle: 'Sirve para calibrar profundidad y dificultad.',
          child: _StepperQuestion(
            value: _currentYear,
            min: 1,
            max: 8,
            labelBuilder: (value) => '$value.º',
            onChanged: (value) => setState(() => _currentYear = value),
          ),
          canContinue: true,
        ),
        _OnboardingPage(
          title: 'Asignaturas habituales',
          subtitle: 'Añade las que quieras ver luego en rutinas y tutor.',
          child: _EditableChipList(
            controller: _subjectCtrl,
            values: _subjects,
            hintText: 'Nombre de la asignatura',
            onAdd: (value) => setState(() {
              if (!_subjects.contains(value)) _subjects.add(value);
            }),
            onRemove: (value) => setState(() => _subjects.remove(value)),
          ),
          canContinue: _subjects.isNotEmpty,
        ),
        _OnboardingPage(
          title: 'Estilo de estudio preferido',
          subtitle:
              'El plan priorizará tareas compatibles con tu forma de aprender.',
          child: _ChoiceQuestion<String>(
            value: _studyStyle,
            options: _studyStyles,
            onChanged: (value) => setState(() => _studyStyle = value),
          ),
          canContinue: true,
        ),
        _OnboardingPage(
          title: 'Horas entre semana',
          subtitle: 'Disponibilidad real por día, no aspiracional.',
          child: _HoursQuestion(
            value: _weekdayHours,
            min: 0.5,
            max: 8,
            onChanged: (value) => setState(() => _weekdayHours = value),
          ),
          canContinue: true,
        ),
        _OnboardingPage(
          title: 'Horas en fin de semana',
          subtitle:
              'La IA usará menos carga si no quieres vivir pegado al calendario.',
          child: _HoursQuestion(
            value: _weekendHours,
            min: 0,
            max: 8,
            onChanged: (value) => setState(() => _weekendHours = value),
          ),
          canContinue: true,
        ),
        _OnboardingPage(
          title: 'Mejor franja de concentración',
          subtitle: 'Las materias difíciles irán aquí cuando sea posible.',
          child: _ChoiceQuestion<String>(
            value: _concentrationWindow,
            options: _timeWindows,
            onChanged: (value) => setState(() => _concentrationWindow = value),
          ),
          canContinue: true,
        ),
        _OnboardingPage(
          title: 'Objetivo principal',
          subtitle: 'El profesor IA decidirá alcance y exigencia con esto.',
          child: _ChoiceQuestion<String>(
            value: _primaryGoal,
            options: _studentGoals,
            onChanged: (value) => setState(() => _primaryGoal = value),
          ),
          canContinue: true,
        ),
      ],
      if (_needsProfessional) ...[
        _OnboardingPage(
          title: 'Sector o rol',
          subtitle: 'Ej: backend junior, diseño UX, consultoría, docencia.',
          child: TextField(
            controller: _sectorRoleCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Sector / rol',
              hintText: 'Escribe tu rol actual o deseado',
            ),
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          canContinue: _sectorRoleCtrl.text.trim().isNotEmpty,
        ),
        _OnboardingPage(
          title: 'Tipos de proyectos habituales',
          subtitle:
              'Añade áreas recurrentes para que la IA planifique con contexto.',
          child: _EditableChipList(
            controller: _projectTypesCtrl,
            values: _projectTypes,
            hintText: 'Ej: APIs, análisis de datos, presentaciones',
            onAdd: (value) => setState(() {
              if (!_projectTypes.contains(value)) _projectTypes.add(value);
            }),
            onRemove: (value) => setState(() => _projectTypes.remove(value)),
          ),
          canContinue: _projectTypes.isNotEmpty,
        ),
        _OnboardingPage(
          title: 'Horas disponibles al día',
          subtitle: 'Tiempo medio para avanzar en aprendizaje o proyectos.',
          child: _HoursQuestion(
            value: _professionalHours,
            min: 0.5,
            max: 8,
            onChanged: (value) => setState(() => _professionalHours = value),
          ),
          canContinue: true,
        ),
        _OnboardingPage(
          title: 'Objetivos a 3-6 meses',
          subtitle:
              'Sé concreto: cambiar de rol, certificarte, lanzar algo, mejorar una skill.',
          child: TextField(
            controller: _professionalGoalsCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Objetivos',
              hintText: 'Qué quieres conseguir y por qué importa',
            ),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
          ),
          canContinue: _professionalGoalsCtrl.text.trim().isNotEmpty,
        ),
      ],
    ];
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final user = SupabaseService.instance.currentUser;
      final userId = user?.id ?? 'local';
      final profilePayload = _buildContext();
      final profileContext = UserProfileContextModel(
        userId: userId,
        profileType: _profileType,
        context: profilePayload,
        onboardingCompleted: true,
        updatedAt: DateTime.now(),
      );

      await ref.read(userProfileContextProvider.notifier).save(profileContext);
      await ref.read(profileProvider.notifier).save(
            _buildLegacyProfile(userId, profilePayload),
          );

      if (mounted) context.go('/today');
    } catch (error) {
      if (mounted) {
        showSnack(context, 'No se pudo guardar el onboarding: $error',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _buildContext() {
    return {
      if (_needsStudent) ...{
        'education_level': _educationLevel,
        'studies': _studiesCtrl.text.trim(),
        'current_year': _currentYear,
        'subjects': List<String>.from(_subjects),
        'study_style': _studyStyle,
        'weekday_hours_per_day': _weekdayHours,
        'weekend_hours_per_day': _weekendHours,
        'concentration_window': _concentrationWindow,
        'primary_goal': _primaryGoal,
      },
      if (_needsProfessional) ...{
        'sector_role': _sectorRoleCtrl.text.trim(),
        'project_types': List<String>.from(_projectTypes),
        'professional_hours_per_day': _professionalHours,
        'professional_goals': _professionalGoalsCtrl.text.trim(),
      },
    };
  }

  UserProfileModel _buildLegacyProfile(
    String userId,
    Map<String, dynamic> context,
  ) {
    final user = SupabaseService.instance.currentUser;
    final displayName = user?.userMetadata?['display_name']?.toString() ??
        user?.email?.split('@').first ??
        'StudyFlow';
    final weeklyHours = _needsStudent
        ? (_weekdayHours * 5 + _weekendHours * 2).round()
        : (_professionalHours * 5).round();

    return UserProfileModel(
      userId: userId,
      displayName: displayName,
      level: context['education_level']?.toString() ?? 'autodidacta',
      degree:
          context['studies']?.toString() ?? context['sector_role']?.toString(),
      yearOfStudy: context['current_year'] as int?,
      subjects: List<String>.from(context['subjects'] as List? ?? const []),
      primaryGoal: context['primary_goal']?.toString() ?? 'trabajo',
      studyStyle: context['study_style']?.toString() ?? 'mixto',
      weeklyHoursAvailable: weeklyHours.clamp(1, 80).toInt(),
      preferredTimes: [context['concentration_window']?.toString() ?? 'tarde'],
      extraContext: context['professional_goals']?.toString(),
      createdAt: DateTime.now(),
    );
  }

  void _next() {
    final pages = _pages;
    if (_page < pages.length - 1) {
      setState(() => _page++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) setState(() => _page--);
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final page = pages[_page.clamp(0, pages.length - 1).toInt()];
    final theme = Theme.of(context);

    return Scaffold(
      body: LoadingOverlay(
        loading: _saving,
        message: 'Guardando contexto…',
        child: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_page + 1) / pages.length,
                minHeight: 3,
                backgroundColor: AppColors.borderSubtle,
                color: AppColors.secondary,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '${_page + 1}/${pages.length}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    Text(
                      'Perfil inteligente',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(page.title, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      page.subtitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    page.child,
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    if (_page > 0)
                      OutlinedButton(
                        onPressed: _saving ? null : _back,
                        child: const Text('Atrás'),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: page.canContinue && !_saving ? _next : null,
                      icon: Icon(
                        _page == pages.length - 1
                            ? Icons.check
                            : Icons.arrow_forward,
                        size: 18,
                      ),
                      label: Text(
                          _page == pages.length - 1 ? 'Guardar' : 'Siguiente'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final String title;
  final String subtitle;
  final Widget child;
  final bool canContinue;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.canContinue,
  });
}

class _ProfileTypeQuestion extends StatelessWidget {
  final ProfileType value;
  final ValueChanged<ProfileType> onChanged;

  const _ProfileTypeQuestion({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ProfileType.values.map((type) {
        final selected = value == type;
        return _SelectionTile(
          selected: selected,
          title: _profileTypeLabels[type]!,
          subtitle: _profileTypeDescriptions[type]!,
          icon: _profileTypeIcons[type]!,
          onTap: () => onChanged(type),
        );
      }).toList(),
    );
  }
}

class _ChoiceQuestion<T> extends StatelessWidget {
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  const _ChoiceQuestion({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.entries.map((entry) {
        return _SelectionTile(
          selected: value == entry.key,
          title: entry.value,
          onTap: () => onChanged(entry.key),
        );
      }).toList(),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onTap;

  const _SelectionTile({
    required this.selected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.secondary.withValues(alpha: 0.10)
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? AppColors.secondary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? AppColors.secondary : AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: selected
                              ? AppColors.secondary
                              : AppColors.textDark,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle,
                      size: 18, color: AppColors.secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableChipList extends StatelessWidget {
  final TextEditingController controller;
  final List<String> values;
  final String hintText;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const _EditableChipList({
    required this.controller,
    required this.values,
    required this.hintText,
    required this.onAdd,
    required this.onRemove,
  });

  void _submit() {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    onAdd(value);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(hintText: hintText),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (values.isEmpty)
          Text(
            'Añade al menos una entrada.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((value) {
              return InputChip(
                label: Text(value),
                onDeleted: () => onRemove(value),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _StepperQuestion extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String Function(int value) labelBuilder;
  final ValueChanged<int> onChanged;

  const _StepperQuestion({
    required this.value,
    required this.min,
    required this.max,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.outlined(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 120,
          child: Center(
            child: Text(
              labelBuilder(value),
              style: theme.textTheme.displaySmall,
            ),
          ),
        ),
        IconButton.outlined(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _HoursQuestion extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _HoursQuestion({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '${_formatHours(value)} h/día',
          style: theme.textTheme.displaySmall
              ?.copyWith(color: AppColors.secondary),
        ),
        const SizedBox(height: 16),
        Slider(
          min: min,
          max: max,
          divisions: ((max - min) * 2).round(),
          value: value.clamp(min, max).toDouble(),
          label: '${_formatHours(value)} h',
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _formatHours(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }
}

const _profileTypeLabels = {
  ProfileType.student: 'Estudiante',
  ProfileType.professional: 'Profesional',
  ProfileType.mixed: 'Estudio y trabajo',
};

const _profileTypeDescriptions = {
  ProfileType.student: 'Exámenes, asignaturas, apuntes y rutinas académicas.',
  ProfileType.professional:
      'Proyectos, aprendizaje aplicado y objetivos de carrera.',
  ProfileType.mixed:
      'Combina calendario académico con objetivos profesionales.',
};

const _profileTypeIcons = {
  ProfileType.student: Icons.school_outlined,
  ProfileType.professional: Icons.work_outline,
  ProfileType.mixed: Icons.schema_outlined,
};

const _educationLevels = {
  'bachillerato': 'Bachillerato',
  'grado': 'Grado',
  'master': 'Máster',
  'fp': 'FP',
  'oposicion': 'Oposición',
  'otros': 'Otros',
};

const _studyStyles = {
  'visual': 'Visual',
  'escrito': 'Escrito',
  'repeticion_espaciada': 'Repetición espaciada',
  'mixto': 'Mixto',
};

const _timeWindows = {
  'manana': 'Mañana',
  'tarde': 'Tarde',
  'noche': 'Noche',
};

const _studentGoals = {
  'aprobar': 'Aprobar',
  'nota_alta': 'Sacar nota alta',
  'oposicion': 'Preparar oposición concreta',
  'aprender': 'Entender a fondo',
  'mantener_ritmo': 'Mantener ritmo sin quemarme',
};
