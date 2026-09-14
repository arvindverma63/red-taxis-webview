import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/phone_launcher.dart';
import '../../../../core/widgets/widgets.dart';

/// Shown in place of the fare when a price quote cannot be obtained. Booking is
/// blocked while this is visible (the review screen disables "Continue"); the
/// customer can retry or call the office to book by phone instead.
///
/// Dialling uses [callOffice] (`tel:` via url_launcher). When no office number
/// is configured the button still shows the "please call the office" guidance
/// rather than dialling a guessed number.
class QuoteUnavailableCard extends StatelessWidget {
  const QuoteUnavailableCard({
    super.key,
    required this.officePhone,
    required this.onRetry,
  });

  /// Office / dispatch number from [AppConfig.supportPhone]. May be empty.
  final String officePhone;

  /// Re-attempt the quote.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.report_gmailerrorred_outlined,
                  color: theme.colorScheme.error),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Couldn't get a price",
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'We were unable to price this trip. Please call the office '
                      'and we will book it for you.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Call office',
            icon: Icons.call,
            onPressed: () => callOffice(context, officePhone),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Try again',
            variant: AppButtonVariant.text,
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
