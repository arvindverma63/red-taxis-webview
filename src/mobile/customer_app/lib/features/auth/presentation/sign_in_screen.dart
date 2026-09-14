import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';
import 'auth_validators.dart';
import 'widgets/auth_widgets.dart';
import 'widgets/social_auth_buttons.dart';

/// Email/username + password sign-in. Submits to `POST /api/v2/customer-auth/login`; on
/// success replaces the stack with Home. Shows a spinner on the CTA while in
/// flight and an inline error banner on failure.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).login(
          usernameOrEmail: _identifier.text.trim(),
          password: _password.text,
        );
    if (ok && mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loading = state.isLoading;

    return AppScaffold(
      // Empty title → back chevron only, matching the GoRide header layout.
      title: '',
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xl,
            ),
            children: [
              const AuthHeader(
                title: 'Welcome back',
                subtitle: 'Sign in to book a taxi, track your driver and see '
                    'your trip history.',
                accent: AuthAccent.wave,
              ),
              const SizedBox(height: AppSpacing.xl),
              AuthErrorBanner(error: state.error),
              AppTextField(
                controller: _identifier,
                label: 'Email or username',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !loading,
                autofillHints: const [AutofillHints.username],
                validator: AuthValidators.usernameOrEmail,
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _password,
                enabled: !loading,
                textInputAction: TextInputAction.done,
                validator: AuthValidators.password,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      loading ? null : () => context.push(Routes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Sign in',
                isLoading: loading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'New here?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: loading ? null : () => context.push(Routes.signUp),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const SocialAuthButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
