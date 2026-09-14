import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/booking_summary.dart';

/// The fare/receipt card at the foot of the ride-details screen (frames
/// `30439:548` / `30439:549`): fare lines above a divided, emphasised total.
///
/// The GoRide mock itemises trip fare, percentage discounts and driver tips;
/// [BookingSummary] carries only a single [BookingSummary.price], so this shows
/// the one real line plus the total rather than fabricating a breakdown. The
/// total label reflects whether the fare is paid (completed/cancelled) or still
/// estimated (live/scheduled).
class FareBreakdownCard extends StatelessWidget {
  const FareBreakdownCard({super.key, required this.booking});

  /// The booking being detailed.
  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settled = booking.isCompleted || booking.isCancelled;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Line(
            label: 'Trip fare',
            value: Fmt.money(booking.price),
          ),
          Divider(
            height: AppSpacing.xl,
            thickness: AppStroke.thin,
            color: theme.colorScheme.outline,
          ),
          _Line(
            label: settled ? 'Total paid' : 'Estimated total',
            value: Fmt.money(booking.price),
            emphasised: true,
          ),
        ],
      ),
    );
  }
}

/// One fare line; [emphasised] renders the bold total.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = emphasised
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium;
    final valueStyle = emphasised
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}
