import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/theme/app_spacing.dart';

/// The social providers shown on the auth screens, in display order.
///
/// Backend social sign-in is not wired for launch (B12). Rather than present
/// real-looking buttons that do nothing, the stack renders each provider as a
/// visibly disabled, non-tappable button under a single "Coming soon" caption,
/// so there is no surprise snackbar on tap. The brand glyph + colour are carried
/// here so the buttons read as recognisable providers once enabled.
enum SocialProvider {
  google('Continue with Google', FontAwesomeIcons.google, Color(0xFFDB4437)),
  apple('Continue with Apple', FontAwesomeIcons.apple, Color(0xFF000000)),
  facebook(
      'Continue with Facebook', FontAwesomeIcons.facebookF, Color(0xFF1877F2));

  const SocialProvider(this.label, this.icon, this.iconColor);

  /// Button label, e.g. "Continue with Google".
  final String label;

  /// Brand glyph rendered at the start of the button.
  final FaIconData icon;

  /// Brand colour for the glyph (the button itself stays neutral white).
  final Color iconColor;
}

/// "or" divider followed by a stack of white, pill-shaped social sign-in
/// buttons with brand icons — mirrors the GoRide auth layout.
///
/// Social sign-in is not available for launch, so the buttons render disabled
/// (muted glyph + label, no tap handler) beneath a "Coming soon" caption.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    this.providers = SocialProvider.values,
  });

  /// Providers to show, in order. Defaults to all of [SocialProvider.values].
  final List<SocialProvider> providers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const _OrDivider(),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Social sign-in is coming soon',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < providers.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          _SocialButton(provider: providers[i]),
        ],
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

/// A single white pill button, rendered disabled: brand glyph at the start,
/// centred label, both muted. There is no tap handler — social sign-in is not
/// available yet, so the button cannot be triggered.
class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.provider});

  final SocialProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledFg = theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return Semantics(
      button: true,
      enabled: false,
      label: '${provider.label} (coming soon)',
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            // No onPressed → button is inert and renders in its disabled state.
            onPressed: null,
            style: OutlinedButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              disabledForegroundColor: disabledFg,
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: FaIcon(
                    provider.icon,
                    size: 20,
                    color: disabledFg,
                  ),
                ),
                Text(
                  provider.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: disabledFg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
