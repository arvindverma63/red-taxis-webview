import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Themed text input with an optional above-field label, consuming the app's
/// [InputDecorationTheme]. Works standalone or inside a [Form] via [validator].
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.textInputAction,
    this.enabled = true,
    this.autofillHints,
    this.validator,
  });

  /// Controls the editable text.
  final TextEditingController? controller;

  /// Optional label rendered above the field as a `labelMedium`.
  final String? label;

  /// Placeholder shown when the field is empty.
  final String? hint;

  /// Error message shown below the field (overridden by [validator] in a Form).
  final String? errorText;

  /// Obscures input for passwords and other secrets.
  final bool obscureText;

  /// Keyboard layout for the field.
  final TextInputType? keyboardType;

  /// Optional leading icon inside the field.
  final IconData? prefixIcon;

  /// Optional trailing widget (e.g. a visibility toggle).
  final Widget? suffixIcon;

  /// Called whenever the text changes.
  final ValueChanged<String>? onChanged;

  /// Keyboard action button behaviour.
  final TextInputAction? textInputAction;

  /// When false the field is greyed out and non-interactive.
  final bool enabled;

  /// Autofill hints for password managers / OS suggestions.
  final Iterable<String>? autofillHints;

  /// Form validator — return an error string or null when valid.
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final field = TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      textInputAction: textInputAction,
      enabled: enabled,
      autofillHints: autofillHints,
      validator: validator,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon,
      ),
    );

    if (label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        field,
      ],
    );
  }
}
