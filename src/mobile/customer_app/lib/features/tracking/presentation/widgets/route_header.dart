import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Floating card over the top of the map showing the trip's pickup and
/// destination as two stacked rows — a green origin pin and a red destination
/// pin joined by a connector — matching the GoRide live-tracking header
/// (frame `30439:403`). Tapping the trailing layers control toggles the map
/// detail/expanded state.
class RouteHeader extends StatelessWidget {
  const RouteHeader({
    super.key,
    required this.pickup,
    required this.destination,
    this.onToggleDetail,
  });

  /// Pickup (origin) address line.
  final String pickup;

  /// Destination (drop-off) address line.
  final String destination;

  /// Tapped when the trailing layers/expand control is pressed.
  final VoidCallback? onToggleDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: theme.colorScheme.outline,
            width: AppStroke.thin,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            _RoutePins(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pickup,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Divider(
                    height: AppSpacing.md,
                    thickness: AppStroke.thin,
                    color: theme.colorScheme.outline,
                  ),
                  Text(
                    destination,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _LayersButton(onTap: onToggleDetail),
          ],
        ),
      ),
    );
  }
}

/// The origin dot → connector → destination pin column on the left of the
/// header. Origin uses [AppColors.success] (green), destination [AppColors.brand]
/// (red) — a deliberate origin↔destination data cue (Peter-confirmed 2026-06-15).
class _RoutePins extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.circle, size: 12, color: AppColors.success),
        SizedBox(
          height: 18,
          child: VerticalDivider(
            width: AppStroke.thin + 1,
            thickness: AppStroke.thin + 1,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const Icon(Icons.location_on, size: 16, color: AppColors.brand),
      ],
    );
  }
}

class _LayersButton extends StatelessWidget {
  const _LayersButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.layers_outlined, size: 20, color: scheme.onSurface),
      ),
    );
  }
}
