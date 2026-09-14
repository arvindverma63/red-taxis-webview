import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Visual styles for [AppButton].
enum AppButtonVariant {
  /// Filled brand button (default primary CTA).
  primary,

  /// Outlined button for secondary actions.
  secondary,

  /// Borderless text button for tertiary actions.
  text,
}

/// The app's single button primitive: themed pill button with primary,
/// secondary and text variants, optional leading icon and a loading state.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
  });

  /// Text shown on the button.
  final String label;

  /// Tap callback. When null the button renders disabled.
  final VoidCallback? onPressed;

  /// Visual style — see [AppButtonVariant].
  final AppButtonVariant variant;

  /// When true, shows a spinner in place of the label and disables the tap.
  final bool isLoading;

  /// When true (default) the button stretches to its parent's width.
  final bool fullWidth;

  /// Optional leading icon shown before the label.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Loading or a null callback both render the button as disabled.
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = _buildChild(context);

    final Widget button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: effectiveOnPressed,
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: effectiveOnPressed,
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          child: child,
        ),
    };

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      // The progress colour follows the button's resolved foreground colour.
      final color = switch (variant) {
        AppButtonVariant.primary => Theme.of(context).colorScheme.onPrimary,
        AppButtonVariant.secondary ||
        AppButtonVariant.text =>
          Theme.of(context).colorScheme.onSurface,
      };
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      );
    }

    if (icon == null) {
      return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
