import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// A GoRide "Choose Payment Method" row (frame 30439:399): a rounded card with
/// a coloured square icon tile on the left, a label + subtitle in the middle,
/// and a brand check on the right when selected. The selected card gains a
/// brand-coloured border + faint brand tint.
///
/// The icon tile colour is supplied per-method ([iconBackground]) so brand
/// marks (cash green, card blue, etc.) read correctly — these are brand/data
/// colours, the documented exception to theme-only styling. All other styling
/// is theme-driven. Feature-local — flag for promotion if reused.
class PaymentMethodRow extends StatelessWidget {
  const PaymentMethodRow({
    super.key,
    required this.label,
    required this.icon,
    this.subtitle,
    this.iconBackground,
    this.iconColor,
    this.selected = false,
    this.onTap,
  });

  /// Method name (e.g. "Cash", "Card").
  final String label;

  /// Glyph for the icon tile.
  final IconData icon;

  /// Optional supporting line (e.g. "Pay the driver directly").
  final String? subtitle;

  /// Optional icon-tile fill. Defaults to a soft brand tint.
  final Color? iconBackground;

  /// Optional icon colour. Defaults to the brand colour.
  final Color? iconColor;

  /// Whether this method is the active selection.
  final bool selected;

  /// Tap callback. Null renders the row disabled.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final borderColor = selected ? scheme.primary : scheme.outline;
    final fill = selected
        ? scheme.primary.withValues(alpha: 0.04)
        : scheme.surface;

    final tileBg = iconBackground ?? scheme.primary.withValues(alpha: 0.12);
    final tileIcon = iconColor ?? scheme.primary;

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // Square branded icon tile.
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 26, color: tileIcon),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.titleMedium),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Brand check appears only when selected (GoRide shows nothing on
          // unselected rows, not an empty radio).
          if (selected)
            Icon(Icons.check, color: scheme.primary, size: 24),
        ],
      ),
    );

    return Material(
      color: fill,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: borderColor,
          width: selected ? 1.5 : AppStroke.thin,
        ),
      ),
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}
