import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/booking_summary.dart';

/// The label → value detail table on the ride-details screen (frames
/// `30439:546` / `30439:548` / `30439:549`): Status (as a [StatusChip]),
/// Payment, Date, Time and the Booking reference.
///
/// The GoRide mock also lists a Transaction ID; [BookingSummary] carries no such
/// field, so it is omitted rather than fabricated. The Booking ID uses the
/// booking's real id.
class RideDetailsTable extends StatelessWidget {
  const RideDetailsTable({super.key, required this.booking});

  /// The booking being detailed.
  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Row(
            label: 'Status',
            value: StatusChip(
              label: booking.statusLabel,
              kind: booking.statusKind,
            ),
            isLast: false,
          ),
          _Row.text(label: 'Payment', value: booking.paymentMethod),
          _Row.text(label: 'Date', value: Fmt.date(booking.scheduledFor)),
          _Row.text(label: 'Time', value: Fmt.time(booking.scheduledFor)),
          _Row.text(label: 'Booking ID', value: booking.id, isLast: true),
        ],
      ),
    );
  }
}

/// One label → value line. [value] is any widget (a chip or a text value).
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.isLast = false});

  /// Convenience for a plain right-aligned text value.
  _Row.text({required this.label, required String value, this.isLast = false})
      : value = _ValueText(value);

  final String label;
  final Widget value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(child: value),
        ],
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.titleMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
