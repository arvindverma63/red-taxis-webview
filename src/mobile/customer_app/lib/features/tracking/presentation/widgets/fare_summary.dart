import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/widgets.dart';

/// A single labelled money row in the fare breakdown.
class FareLine {
  const FareLine(this.label, this.amount, {this.emphasised = false});

  final String label;
  final num amount;

  /// When true the row renders as the bold total.
  final bool emphasised;
}

/// The fare/receipt breakdown shown on the GoRide "Ride completed" frame
/// (`30431:30709`): a titled card listing fare components and a bold total,
/// money formatted via [Fmt.money] for locale-correct thousands + 2dp.
class FareSummary extends StatelessWidget {
  const FareSummary({
    super.key,
    required this.lines,
    this.title = 'Trip receipt',
    this.paymentLabel,
  });

  /// Ordered fare rows; mark the total row [FareLine.emphasised].
  final List<FareLine> lines;

  /// Card heading.
  final String title;

  /// Optional payment-method line shown under the breakdown (e.g. "Cash").
  final String? paymentLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          for (final line in lines) ...[
            _Row(line: line),
            if (line != lines.last) const SizedBox(height: AppSpacing.sm),
          ],
          if (paymentLabel != null) ...[
            Divider(
              height: AppSpacing.xl,
              thickness: AppStroke.thin,
              color: theme.colorScheme.outline,
            ),
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined,
                    size: 18, color: theme.colorScheme.onSurface),
                const SizedBox(width: AppSpacing.sm),
                Text(paymentLabel!, style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.line});

  final FareLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = line.emphasised
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium;
    final valueStyle = line.emphasised
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(line.label, style: labelStyle),
        Text(Fmt.money(line.amount), style: valueStyle),
      ],
    );
  }
}
