import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/phone_launcher.dart';
import '../../../core/widgets/widgets.dart';
import '../application/booking_draft_controller.dart';
import '../domain/booking_draft.dart';
import '../domain/vehicle_type.dart';
import 'widgets/widgets.dart';

/// Success screen after a request is sent. The operator still has to ACCEPT the
/// request (webbooking → dispatch model), so the copy says "awaiting
/// confirmation". Shows a summary and a "Call office" shortcut.
class BookingConfirmScreen extends ConsumerWidget {
  const BookingConfirmScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Read (not watch) — the draft is reset on "Done"; we snapshot it for the
    // summary so the page doesn't blank when the draft clears.
    final draft = ref.read(bookingDraftProvider);
    final config = AppConfig.fromEnvironment();

    return AppScaffold(
      title: 'Booking sent',
      leading: const SizedBox.shrink(), // no back — this is a terminal step
      body: ListView(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Request sent',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Awaiting confirmation from the office. We\'ll let you know as soon '
            'as your ride is accepted.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: StatusChip(
              label: 'Ref $requestId',
              kind: StatusKind.pending,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SummaryCard(draft: draft),
          if (_isOutOfHours(draft, config)) ...[
            const SizedBox(height: AppSpacing.lg),
            const OutOfHoursNote(),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Call office',
            variant: AppButtonVariant.secondary,
            icon: Icons.call,
            onPressed: () => callOffice(context, config.supportPhone),
          ),
        ],
      ),
      bottomBar: AppButton(
        label: 'Done',
        onPressed: () {
          ref.read(bookingDraftProvider.notifier).reset();
          context.go(Routes.home);
        },
      ),
    );
  }

  /// Out-of-hours when an ASAP ride is requested while the office is closed, or
  /// a scheduled ride falls in the closed window.
  bool _isOutOfHours(BookingDraft draft, AppConfig config) {
    final when = draft.scheduledFor ?? DateTime.now();
    return config.isOutsideOperatingHours(when.hour);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vehicle = vehicleById(draft.vehicleId);
    final when = draft.isAsap
        ? 'Now (ASAP)'
        : Fmt.dateTime(draft.scheduledFor!);
    final price = draft.paymentMethod == 'account'
        ? draft.quote?.priceAccount
        : draft.quote?.priceCash;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(theme, Icons.my_location, 'Pickup',
              draft.pickup?.description ?? '—'),
          const SizedBox(height: AppSpacing.md),
          _row(theme, Icons.location_on, 'Destination',
              draft.dropoff?.description ?? '—'),
          const Divider(height: AppSpacing.xl),
          _row(theme, Icons.schedule, 'When', when),
          const SizedBox(height: AppSpacing.md),
          _row(theme, Icons.directions_car_outlined, 'Vehicle', vehicle.name),
          const SizedBox(height: AppSpacing.md),
          _row(theme, Icons.payments_outlined, 'Payment',
              _paymentLabel(draft.paymentMethod)),
          if (price != null) ...[
            const SizedBox(height: AppSpacing.md),
            _row(theme, Icons.receipt_long_outlined, 'Estimated fare',
                Fmt.money(price)),
          ],
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _paymentLabel(String method) => switch (method) {
        'cash' => 'Cash',
        'card' => 'Card',
        'applePay' => 'Apple Pay',
        'account' => 'Billed to account',
        _ => method,
      };
}
