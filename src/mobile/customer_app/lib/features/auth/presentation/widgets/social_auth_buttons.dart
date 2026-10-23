import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
    // Apple's guidelines allow a custom button as long as it is solid black or
    // white with the Apple logo and "Sign in with Apple" wording.
    final appleBg = isDark ? Colors.white : Colors.black;
    final appleFg = isDark ? Colors.black : Colors.white;
    return Column(
      children: [
        const _OrDivider(),
        const SizedBox(height: AppSpacing.lg),
        if (showApple)
          _SocialButton(
            label: 'Sign in with Apple',
            icon: FaIcon(FontAwesomeIcons.apple, size: 22, color: appleFg),
            onPressed: loading ? null : onApple,
            background: appleBg,
            foreground: appleFg,
            borderColor: appleBg,
          ),
        if (showApple && showGoogle) const SizedBox(height: AppSpacing.md),
        if (showGoogle)
          _SocialButton(
            label: 'Continue with Google',
            icon: const FaIcon(
              FontAwesomeIcons.google,
              size: 20,
              color: Color(0xFFDB4437),
            ),
            onPressed: loading ? null : onGoogle,
            background: theme.colorScheme.surface,
            foreground: theme.colorScheme.onSurface,
            borderColor: theme.colorScheme.outline,
          ),
      ],
    );
  }
}

/// Full-width pill button shared by every social provider so they line up:
/// same height, logo pinned left, label centred.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.borderColor,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: background.withValues(alpha: 0.5),
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: borderColor, width: AppStroke.thin),
          shape: const StadiumBorder(),
          textStyle: theme.textTheme.titleMedium,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: icon,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
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
