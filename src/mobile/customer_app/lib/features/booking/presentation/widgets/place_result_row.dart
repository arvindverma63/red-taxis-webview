import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// A GoRide place-suggestion row: a hollow circular pin on the left, a two-line
/// title/subtitle in the middle, and an optional trailing distance label +
/// bookmark affordance on the right.
///
/// Distinct from `core/widgets` `AppListTile` (which uses a brand-filled circle
/// and no distance/bookmark column) — this matches the search results layout in
/// frames 30439:393/394. Theme-only. Feature-local — flag for promotion if the
/// distance+bookmark pattern is reused.
class PlaceResultRow extends StatelessWidget {
  const PlaceResultRow({
    super.key,
    required this.title,
    this.subtitle,
    this.distanceLabel,
    this.onTap,
    this.onBookmark,
    this.bookmarked = false,
    this.icon = Icons.location_on_outlined,
  });

  /// Primary text (place name).
  final String title;

  /// Optional secondary text (full address).
  final String? subtitle;

  /// Optional distance label shown before the bookmark (e.g. "0.4 km").
  final String? distanceLabel;

  /// Row tap callback.
  final VoidCallback? onTap;

  /// Optional bookmark tap callback. When null the bookmark icon is hidden.
  final VoidCallback? onBookmark;

  /// Whether the place is bookmarked (filled vs outline glyph).
  final bool bookmarked;

  /// Leading glyph inside the hollow circle.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hollow circular pin (GoRide uses a 1px ring, not a filled chip).
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outline, width: AppStroke.thin),
            ),
            child: Icon(icon, size: 20, color: scheme.onSurface),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
          if (distanceLabel != null && distanceLabel!.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(distanceLabel!, style: theme.textTheme.bodySmall),
          ],
          if (onBookmark != null) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onBookmark,
              icon: Icon(
                bookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 22,
                color: bookmarked ? scheme.primary : scheme.onSurface,
              ),
              tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark',
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: row,
    );
  }
}
