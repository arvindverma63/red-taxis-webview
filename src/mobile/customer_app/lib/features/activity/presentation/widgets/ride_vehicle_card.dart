import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/booking_summary.dart';
import 'vehicle_avatar.dart';

/// The vehicle summary card at the top of the ride-details screen (frames
/// `30439:546` / `30439:548` / `30439:549`): a vehicle glyph, the tariff name
/// with a passengers caption, and the fare with a green verified badge.
///
/// The GoRide mock also shows an ETA ("3–5 mins") and a struck-through original
/// price; neither exists on [BookingSummary], so they are omitted rather than
/// invented — the layout collapses cleanly to name · passengers · price.
class RideVehicleCard extends StatelessWidget {
  const RideVehicleCard({super.key, required this.booking});

  /// The booking being detailed.
  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showVerified = !booking.isCancelled;

    return AppCard(
      child: Row(
        children: [
          VehicleAvatar(vehicleName: booking.vehicleName, size: 52),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  booking.vehicleName,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 16,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      booking.passengers == 1
                          ? '1 passenger'
                          : '${booking.passengers} passengers',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showVerified) ...[
                const Icon(Icons.verified, size: 18, color: AppColors.success),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                Fmt.money(booking.price),
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
