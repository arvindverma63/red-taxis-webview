import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// A small circular icon button used for the GoRide accent controls: the "add
/// stop" (+) circle next to the destination field, the map recenter / back
/// chips floating over the map, and the close affordance.
///
/// Two surfaces:
/// - [CircleIconButton.outlined] — transparent fill, brand-tinted hairline ring
///   (the GoRide "+" add-stop button).
/// - [CircleIconButton.filled] — solid surface with a soft shadow (the floating
///   map controls).
///
/// Theme-only: colours come from [Theme.of] / [ColorScheme]. Feature-local —
/// note for promotion to `core/widgets` if reused outside booking.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 48,
    this.iconColor,
    this.tooltip,
  })  : _filled = false;

  const CircleIconButton.filled({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconColor,
    this.tooltip,
  }) : _filled = true;

  /// Glyph rendered in the centre.
  final IconData icon;

  /// Tap callback — null renders the button disabled (dimmed, no ripple).
  final VoidCallback? onTap;

  /// Diameter in logical pixels.
  final double size;

  /// Optional icon colour override (defaults to the brand colour for the
  /// outlined style, the on-surface colour for the filled style).
  final Color? iconColor;

  /// Accessibility / long-press tooltip.
  final String? tooltip;

  final bool _filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    final Color resolvedIcon = iconColor ??
        (_filled ? scheme.onSurface : scheme.primary);

    final decoration = _filled
        ? BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.4),
              width: AppStroke.thin,
            ),
          );

    final button = Container(
      width: size,
      height: size,
      decoration: decoration,
      child: Icon(
        icon,
        size: size * 0.42,
        color: enabled ? resolvedIcon : scheme.outline,
      ),
    );

    final tappable = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: button,
      ),
    );

    if (tooltip == null) return tappable;
    return Tooltip(message: tooltip!, child: tappable);
  }
}
