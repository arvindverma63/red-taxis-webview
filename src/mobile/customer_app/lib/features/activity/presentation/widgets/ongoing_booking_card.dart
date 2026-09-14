import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/booking_summary.dart';
import 'route_path.dart';
import 'vehicle_avatar.dart';

/// The hero "Ongoing" trip presentation (frame `30439:426`): a header line
/// (vehicle avatar, destination + "date · time" caption, price + payment), an
/// inset route block (green pickup pin → red destination pin), and a full-width
/// "Track Route" CTA. Only live trips show this richer layout; scheduled, past
/// and cancelled trips use the compact [BookingListRow].
class OngoingBookingCard extends StatelessWidget {
  const OngoingBookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.onTrack,
  });

  /// The active booking to render.
  final BookingSummary booking;

  /// Tap on the card body — opens ride details.
  final VoidCallback? onTap;

  /// Tap on the "Track Route" CTA — opens live tracking. Hidden when null.
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: vehicle · destination · date — price · payment ──────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    booking.paymentMethod,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Inset route block ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: theme.colorScheme.outline,
                width: AppStroke.thin,
              ),
            ),
            child: RoutePath(pickup: booking.pickup, dropoff: booking.dropoff),
          ),

          // ── Track Route CTA ─────────────────────────────────────────────
          if (onTrack != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Track Route',
              variant: AppButtonVariant.secondary,
              onPressed: onTrack,
            ),
          ],
        ],
      ),
    );
  }
}
