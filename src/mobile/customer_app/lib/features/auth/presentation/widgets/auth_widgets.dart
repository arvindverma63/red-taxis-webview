import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// GoRide-style auth header: a large bold headline with a trailing sparkle
/// accent, over a muted two-line subtitle.
///
/// The sparkle is rendered as a brand-tinted icon appended to the headline so
/// it inherits the headline's baseline and scales with the text.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.accent = AuthAccent.sparkle,
  });

  /// Headline text, e.g. "Create your account".
  final String title;

  /// Muted supporting line(s) under the headline.
  final String subtitle;

  /// Which glyph trails the headline.
  final AuthAccent accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: title,
            style: theme.textTheme.displayMedium,
            children: [
              const TextSpan(text: '  '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  accent.icon,
                  size: 26,
                  color: accent.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(subtitle, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// Headline accent glyphs available to [AuthHeader].
enum AuthAccent {
  /// A warm sparkle — used on the sign-up "create account" headline.
  sparkle(Icons.auto_awesome, Color(0xFFF7B500)),

  /// A waving hand — used on the sign-in "welcome back" headline.
  wave(Icons.waving_hand_rounded, Color(0xFFF7B500));

  const AuthAccent(this.icon, this.color);

  final IconData icon;
  final Color color;
}

/// "I agree to the Terms & Conditions" checkbox row for sign-up.
///
/// The checkbox uses the brand colour when ticked; the "Terms & Conditions"
/// fragment is a tappable brand-coloured link. The host screen owns the checked
/// state and the link tap so the button can gate on agreement.
class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onTermsTap,
    this.enabled = true,
  });

  /// Whether the box is ticked.
  final bool value;

  /// Called with the new value when the box (or its label) is toggled.
  final ValueChanged<bool> onChanged;

  /// Called when the "Terms & Conditions" link is tapped.
  final VoidCallback onTermsTap;

  /// When false the whole row is non-interactive.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: enabled ? (v) => onChanged(v ?? false) : null,
            activeColor: AppColors.brand,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'I agree to the ',
              style: theme.textTheme.bodyMedium,
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: enabled ? onTermsTap : null,
                    child: Text(
                      'Terms & Conditions',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline error banner shown above a form's submit button when an auth action
/// fails. Renders nothing when [error] is null.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Something went wrong. Please try again.';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.40),
            width: AppStroke.thin,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                size: 20, color: theme.colorScheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A password [AppTextField] with a built-in show/hide visibility toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hint,
    this.textInputAction,
    this.validator,
    this.autofillHints = const [AutofillHints.password],
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      obscureText: _obscured,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      autofillHints: widget.autofillHints,
      prefixIcon: Icons.lock_outline,
      suffixIcon: IconButton(
        icon: Icon(_obscured ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => _obscured = !_obscured),
        tooltip: _obscured ? 'Show password' : 'Hide password',
      ),
    );
  }
}
