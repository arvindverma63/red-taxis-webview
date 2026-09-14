import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../domain/booking_summary.dart';
import 'vehicle_avatar.dart';

/// The compact, divided activity row used by the Scheduled / Completed /
/// Canceled tabs (frames `30439:427` / `30439:429` / `30439:431`): a vehicle
/// avatar, the destination name with a "date · time" caption, and a right
/// column carrying the price above a secondary line.
///
/// The secondary line varies by tab: the payment method (scheduled/completed),
/// the scheduled date (scheduled list), or a red "Canceled & Refunded" status
/// (canceled). Pass it via [trailingLabel] + [trailingDanger].
class BookingListRow extends StatelessWidget {
  const BookingListRow({
    super.key,
    required this.booking,
    required this.trailingLabel,
    this.trailingDanger = false,
    this.onTap,
  });

  /// The booking to render.
  final BookingSummary booking;

  /// Secondary right-column line under the price.
  final String trailingLabel;

  /// When true the [trailingLabel] renders in the brand/error colour (the
  /// "Canceled & Refunded" treatment).
  final bool trailingDanger;

  /// Tap callback — opens the ride details.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          VehicleAvatar(vehicleName: booking.vehicleName),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  booking.dropoff.description,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Fmt.dateTime(booking.scheduledFor),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Fmt.money(booking.price),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                trailingLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: trailingDanger ? AppColors.brand : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
