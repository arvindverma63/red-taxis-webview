import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';
import 'auth_validators.dart';
import 'widgets/auth_widgets.dart';

/// Email field → `POST /api/v2/customer-auth/forgot-password` (always 200, never reveals
/// whether the account exists). On success swaps to a "Check your email"
/// confirmation state.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .forgotPassword(_email.text.trim());
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(authControllerProvider);
    final loading = state.isLoading;

    return AppScaffold(
      title: 'Forgot password',
      body: _sent
          ? _Confirmation(email: _email.text.trim())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                children: [
                  Text('Reset your password',
                      style: theme.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Enter the email on your account and we will send a link to '
                    'set a new password.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AuthErrorBanner(error: state.error),
                  AppTextField(
                    controller: _email,
                    label: 'Email',
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    prefixIcon: Icons.mail_outline,
                    enabled: !loading,
                    autofillHints: const [AutofillHints.email],
                    validator: AuthValidators.email,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Send reset link',
                    isLoading: loading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.mark_email_read_outlined,
            size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Check your email',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'If $email is registered, a password reset link is on its way. '
          'Follow it to set a new password.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: 'Back to sign in',
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}
