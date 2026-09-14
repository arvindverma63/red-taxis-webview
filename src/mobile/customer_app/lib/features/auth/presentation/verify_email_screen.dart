import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_widgets.dart';

/// Email verification. Two modes off the deep-link query params:
/// - With a `token`: auto-calls `POST /api/v2/customer-auth/verify-email` on open and
///   shows the outcome.
/// - Without a token (post-signup prompt): shows "Verify your email" with a
///   resend button (`POST /api/v2/customer-auth/send-verify-email`).
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email, this.token});

  final String email;
  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _verifying = false;
  bool _verified = false;
  bool _resent = false;

  bool get _hasToken => (widget.token ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasToken && widget.email.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    final ok = await ref.read(authControllerProvider.notifier).verifyEmail(
          email: widget.email,
          token: widget.token!,
        );
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _verified = ok;
    });
  }

  Future<void> _resend() async {
    setState(() => _resent = false);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .sendVerifyEmail(widget.email);
    if (ok && mounted) setState(() => _resent = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(authControllerProvider);
    final loading = state.isLoading;

    // Token mode while the verify call is running.
    if (_hasToken && _verifying) {
      return const AppScaffold(
        title: 'Verify email',
        body: LoadingView(message: 'Verifying your email…'),
      );
    }

    // Token mode, verified successfully.
    if (_hasToken && _verified) {
      return AppScaffold(
        title: 'Verify email',
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          children: [
            const SizedBox(height: AppSpacing.xl),
            Icon(Icons.verified_outlined,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.xl),
            Text('Email verified',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Thanks — your email address is confirmed.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Continue',
              onPressed: () => context.go(Routes.home),
            ),
          ],
        ),
      );
    }

    // Token mode that failed → fall through to the prompt + resend, surfacing
    // the error so the user can retry from the email.
    return AppScaffold(
      title: 'Verify email',
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        children: [
          const SizedBox(height: AppSpacing.lg),
          Icon(Icons.mark_email_unread_outlined,
              size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.xl),
          Text('Verify your email',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.email.isEmpty
                ? 'Open the link in the email we sent you to confirm your '
                    'address.'
                : 'We sent a verification link to ${widget.email}. Open it to '
                    'confirm your address.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AuthErrorBanner(error: state.error),
          if (_resent)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                'Verification email sent.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.primary),
                textAlign: TextAlign.center,
              ),
            ),
          AppButton(
            label: 'Resend email',
            icon: Icons.refresh,
            isLoading: loading,
            onPressed: widget.email.isEmpty ? null : _resend,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Continue',
            variant: AppButtonVariant.text,
            onPressed: () => context.go(Routes.home),
          ),
        ],
      ),
    );
  }
}
