import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/loading_overlay.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await SupabaseService.instance.signInWithPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      if (mounted) context.go('/today');
    } catch (e) {
      if (mounted) showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supaConfigured = SupabaseService.instance.isConfigured;
    final t = Theme.of(context);

    return Scaffold(
      body: LoadingOverlay(
        loading: _loading,
        child: Stack(
          children: [
            // Decoración de fondo
            Positioned(
              top: -120,
              right: -120,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      AppColors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.15),
                      AppColors.secondary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),

                        // Logo / símbolo
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              gradient: AppColors.heroGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 30),
                          ),
                        ),

                        const SizedBox(height: 28),

                        Text(
                          'StudyFlow',
                          textAlign: TextAlign.center,
                          style: t.textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Tu espacio para estudiar,\ntrabajar y crecer.',
                          textAlign: TextAlign.center,
                          style: t.textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textMuted),
                        ),

                        const SizedBox(height: 48),

                        if (!supaConfigured)
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 20, color: AppColors.warning),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Configura Supabase en .env para habilitar la sincronización.',
                                    style: t.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline, size: 20),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Requerido' : null,
                        ),

                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _pass,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Mínimo 6 caracteres'
                              : null,
                        ),

                        const SizedBox(height: 28),

                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: supaConfigured ? _login : null,
                            child: const Text('Entrar'),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () => context.go('/signup'),
                          child: const Text('¿No tienes cuenta? Regístrate'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
