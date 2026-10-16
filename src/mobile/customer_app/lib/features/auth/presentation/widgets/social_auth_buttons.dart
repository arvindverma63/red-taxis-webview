import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_spacing.dart';

/// "or" divider followed by a working "Continue with Google" button.
///
/// Renders nothing until Google sign-in is configured for this platform
/// ([AppConfig.googleSignInEnabled]), so no unfinished sign-in options are shown.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.onGoogle,
    this.loading = false,
  });

  /// Called when the user taps "Continue with Google".
  final VoidCallback onGoogle;

  /// Disables the button while a sign-in is in progress.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.googleSignInEnabled) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      children: [
        const _OrDivider(),
        const SizedBox(height: AppSpacing.lg),
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
