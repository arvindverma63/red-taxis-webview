import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';
import 'auth_validators.dart';
import 'widgets/auth_widgets.dart';

/// Completes a password reset. Reads `email` + `token` from the deep-link query
/// params (the email links to `{BaseUrl}/reset-password?email=...&token=...`),
/// takes a new password (+ confirm), and submits to
/// `POST /api/v2/customer-auth/reset-password`. On success shows a brief success state
/// then routes to Sign in. Renders an invalid-link state when params are
/// missing (e.g. the screen was opened without a token).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.token,
  });

  final String email;
  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _done = false;

  bool get _hasValidLink =>
      widget.email.isNotEmpty && widget.token.isNotEmpty;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).resetPassword(
          email: widget.email,
          token: widget.token,
          newPassword: _password.text,
        );
    if (ok && mounted) {
      setState(() => _done = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Password updated. Please sign in.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(authControllerProvider);
    final loading = state.isLoading;

    if (!_hasValidLink) {
      return AppScaffold(
        title: 'Reset password',
        body: ErrorView(
          icon: Icons.link_off,
          message: 'This password link is invalid or has expired. Request a '
              'new one from the sign-in screen.',
          retryLabel: 'Go to sign in',
          onRetry: () => context.go(Routes.signIn),
        ),
      );
    }

    if (_done) {
      return AppScaffold(
        title: 'Reset password',
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          children: [
            const SizedBox(height: AppSpacing.xl),
            Icon(Icons.check_circle_outline,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.xl),
            Text('Password updated',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your password has been updated. Sign in with your new password.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Sign in',
              onPressed: () => context.go(Routes.signIn),
            ),
          ],
        ),
      );
    }

    return AppScaffold(
      title: 'Reset password',
      body: AutofillGroup(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            children: [
              Text('Create a new password',
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Setting a new password for ${widget.email}.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              AuthErrorBanner(error: state.error),
              PasswordField(
                controller: _password,
                label: 'New password',
                enabled: !loading,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: AuthValidators.password,
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _confirm,
                label: 'Confirm new password',
                enabled: !loading,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: AuthValidators.confirmPassword(() => _password.text),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Reset password',
                isLoading: loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
