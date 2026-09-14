import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// A GoRide-style account/settings row: a flat leading glyph, a single-line
/// label and a trailing chevron (or custom trailing). Unlike `core`'s
/// [AppListTile] — which wraps the icon in a 44px brand-tinted circle and
/// supports subtitles — GoRide's Account list rows are compact and flat: just
/// `icon · label · chevron`. This is the faithful row for the Account screen's
/// grouped menu, kept feature-local so it doesn't disturb the shared kit.
///
/// Set [destructive] for the Logout row, which renders the icon, label and
/// chevron in the error/brand tone per the design.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  /// Leading glyph (flat, no circle).
  final IconData icon;

  /// Single-line row label.
  final String label;

  /// Tap callback for the whole row.
  final VoidCallback? onTap;

  /// Optional trailing widget. Defaults to a chevron when null.
  final Widget? trailing;

  /// When true the row reads in the error tone (used for Logout).
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // GoRide draws the leading glyphs in the primary text tone; the Logout row
    // is the lone exception, drawn in the brand/error tone.
    final foreground =
        destructive ? scheme.error : theme.textTheme.titleMedium?.color;
    final chevronColor =
        destructive ? scheme.error : theme.textTheme.bodySmall?.color;

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: foreground),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(color: foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing ??
              Icon(Icons.chevron_right, size: 22, color: chevronColor),
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(onTap: onTap, child: row);
  }
}
