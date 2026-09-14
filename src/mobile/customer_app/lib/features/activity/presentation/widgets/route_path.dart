import 'package:flutter/material.dart';

import '../../../../core/domain/place.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// The pickup → dropoff route block used on the GoRide activity cards and ride
/// details (frames `30439:426` / `30439:546`): a green origin pin and a red
/// destination pin joined by a dotted connector, each beside its place name,
/// with a hairline divider between the two rows.
///
/// Pins use semantic *data* colours — pickup/origin [AppColors.success] (green),
/// destination [AppColors.brand] (red) — a deliberate origin↔destination cue
/// (Peter-confirmed 2026-06-15, keep), matching `booking/location_search_card`
/// and `tracking/route_header`.
///
/// Feature-local — flag for promotion if reused outside activity.
class RoutePath extends StatelessWidget {
  const RoutePath({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.showPostcodes = false,
  });

  /// Pickup (origin) place.
  final Place pickup;

  /// Drop-off (destination) place.
  final Place dropoff;

  /// When true, each row shows the place's postcode as a second line.
  final bool showPostcodes;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PinRail(),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlaceLine(place: pickup, showPostcode: showPostcodes),
              Divider(
                height: AppSpacing.lg,
                thickness: AppStroke.thin,
                color: Theme.of(context).colorScheme.outline,
              ),
              _PlaceLine(place: dropoff, showPostcode: showPostcodes),
            ],
          ),
        ),
      ],
    );
  }
}

/// The green-dot → dotted-connector → red-pin rail down the left edge, sized to
/// align with the two stacked place lines.
class _PinRail extends StatelessWidget {
  const _PinRail();

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, size: 18, color: AppColors.success),
          _DottedConnector(color: outline),
          const Icon(Icons.location_on, size: 18, color: AppColors.brand),
        ],
      ),
    );
  }
}

/// A short vertical dotted line connecting the two pins.
class _DottedConnector extends StatelessWidget {
  const _DottedConnector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      width: 2,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
          (_) => Container(
            width: 2,
            height: 2,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// One place name (and optional postcode) aligned to its pin.
class _PlaceLine extends StatelessWidget {
  const _PlaceLine({required this.place, required this.showPostcode});

  final Place place;
  final bool showPostcode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          place.description,
          style: theme.textTheme.bodyLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (showPostcode && (place.postcode?.isNotEmpty ?? false)) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            place.postcode!,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
