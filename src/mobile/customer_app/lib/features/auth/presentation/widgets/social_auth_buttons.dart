import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_spacing.dart';

/// "or" divider followed by "Sign in with Apple" (iOS) and "Continue with Google".
///
/// Each button renders only when its provider is configured for this platform
/// ([AppConfig.appleSignInEnabled] / [AppConfig.googleSignInEnabled]), so no
/// unfinished sign-in options are shown.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.onGoogle,
    this.onApple,
    this.loading = false,
  });

  /// Called when the user taps "Continue with Google".
  final VoidCallback onGoogle;

  /// Called when the user taps "Sign in with Apple".
  final VoidCallback? onApple;

  /// Disables the button while a sign-in is in progress.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final showApple = AppConfig.appleSignInEnabled && onApple != null;
    final showGoogle = AppConfig.googleSignInEnabled;
    if (!showApple && !showGoogle) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        const _OrDivider(),
        const SizedBox(height: AppSpacing.lg),
        if (showApple)
          IgnorePointer(
            ignoring: loading,
            child: Opacity(
              opacity: loading ? 0.5 : 1,
              child: SignInWithAppleButton(
                onPressed: onApple!,
                height: 56,
                borderRadius: const BorderRadius.all(Radius.circular(28)),
                style: isDark
                    ? SignInWithAppleButtonStyle.white
                    : SignInWithAppleButtonStyle.black,
              ),
            ),
          ),
        if (showApple && showGoogle) const SizedBox(height: AppSpacing.md),
        if (showGoogle)
          SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: loading ? null : onGoogle,
            style: OutlinedButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              minimumSize: const Size.fromHeight(56),
              side: BorderSide(
                color: theme.colorScheme.outline,
                width: AppStroke.thin,
              ),
              shape: const StadiumBorder(),
              textStyle: theme.textTheme.titleMedium,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: FaIcon(
                    FontAwesomeIcons.google,
                    size: 20,
                    color: Color(0xFFDB4437),
                  ),
                ),
                Text(
                  'Continue with Google',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A centred "or" label flanked by hairline rules.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = Expanded(
      child: Divider(
        color: theme.colorScheme.outline,
        thickness: AppStroke.thin,
        height: AppStroke.thin,
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            'or',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        line,
      ],
    );
  }
}
