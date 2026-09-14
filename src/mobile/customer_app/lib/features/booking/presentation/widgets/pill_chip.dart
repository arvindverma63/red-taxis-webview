import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// An outlined, pill-shaped chip with an optional leading icon — the GoRide
/// quick-shortcut control used for "Select from map", "Home", "Office",
/// "Apartment" etc. Hugs its label width so a row of them scrolls horizontally.
///
/// When [selected] the chip fills with a soft brand tint and the ring + icon go
/// brand. Theme-only styling. Feature-local — flag for promotion if reused.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
    this.iconColor,
  });

  /// Chip text.
  final String label;

  /// Optional leading glyph.
  final IconData? icon;

  /// Tap callback. Null renders a static (non-interactive) chip.
  final VoidCallback? onTap;

  /// Whether the chip reads as selected (brand tint + ring).
  final bool selected;

  /// Optional override for the leading icon colour (e.g. GoRide tints the
  /// "Select from map" pin in brand even when unselected).
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final ringColor = selected ? scheme.primary : scheme.outline;
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.08)
        : scheme.surface;
    final resolvedIconColor =
        iconColor ?? (selected ? scheme.primary : scheme.onSurface);

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: resolvedIconColor),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return Material(
      color: bg,
      shape: StadiumBorder(
        side: BorderSide(color: ringColor, width: AppStroke.thin),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}
