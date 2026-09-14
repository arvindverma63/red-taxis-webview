import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/domain/place.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../application/booking_draft_controller.dart';
import '../application/quote_controller.dart';
import '../domain/booking_draft.dart';
import '../domain/quote.dart';
import '../domain/vehicle_type.dart';
import 'widgets/widgets.dart';

/// Review + configure the ride: route map, vehicle class, fare quote and the
/// schedule (Now or a future date/time). "Continue" advances to payment.
class BookingReviewScreen extends ConsumerStatefulWidget {
  const BookingReviewScreen({super.key});

  @override
  ConsumerState<BookingReviewScreen> createState() =>
      _BookingReviewScreenState();
}

class _BookingReviewScreenState extends ConsumerState<BookingReviewScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch an initial quote once the first frame is up (draft is ready).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quoteControllerProvider.notifier).refresh();
    });
  }

  void _selectVehicle(String id) {
    ref.read(bookingDraftProvider.notifier).setVehicle(id);
    ref.read(quoteControllerProvider.notifier).refresh();
  }

  Future<void> _pickSchedule() async {
    final draft = ref.read(bookingDraftProvider);
    final now = DateTime.now();
    final initial = draft.scheduledFor ?? now.add(const Duration(minutes: 30));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    var scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // Guard against a past time on today's date.
    if (scheduled.isBefore(now)) scheduled = now.add(const Duration(minutes: 15));

    ref.read(bookingDraftProvider.notifier).setSchedule(scheduled);
    ref.read(quoteControllerProvider.notifier).refresh();
  }

  void _setAsap() {
    ref.read(bookingDraftProvider.notifier).setSchedule(null);
    ref.read(quoteControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final quoteAsync = ref.watch(quoteControllerProvider);
    final theme = Theme.of(context);
    final config = AppConfig.fromEnvironment();
    final whenHour = (draft.scheduledFor ?? DateTime.now()).hour;
    final outOfHours = config.isOutsideOperatingHours(whenHour);

    return AppScaffold(
      title: 'Review ride',
      padded: false,
      body: ListView(
        children: [
          // Route map (pins are placeholders until Maps keys land).
          SizedBox(
            height: 220,
            child: MapView(markers: _markers(draft)),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RouteSummary(draft: draft),
                const SizedBox(height: AppSpacing.xl),

                Text('Vehicle', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _VehicleSelector(
                  selectedId: draft.vehicleId,
                  passengers: draft.passengers,
                  onSelect: _selectVehicle,
                ),
                const SizedBox(height: AppSpacing.xl),

                Text('When', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _ScheduleSelector(
                  scheduledFor: draft.scheduledFor,
                  onAsap: _setAsap,
                  onPick: _pickSchedule,
                ),
                if (outOfHours) ...[
                  const SizedBox(height: AppSpacing.md),
                  const OutOfHoursNote(),
                ],
                const SizedBox(height: AppSpacing.xl),

                _QuoteCard(
                  quoteAsync: quoteAsync,
                  paymentMethod: draft.paymentMethod,
                  officePhone: config.supportPhone,
                  onRetry: () =>
                      ref.read(quoteControllerProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: AppButton(
        label: 'Continue',
        onPressed: quoteAsync.maybeWhen(
          data: (q) => q == null ? null : () => context.push(Routes.paymentMethod),
          orElse: () => null,
        ),
        isLoading: quoteAsync.isLoading,
      ),
    );
  }

  Set<Marker> _markers(BookingDraft draft) {
    final markers = <Marker>{};
    final p = draft.pickup;
    final d = draft.dropoff;
    if (p?.lat != null && p?.lng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(p!.lat!, p.lng!),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ));
    }
    if (d?.lat != null && d?.lng != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(d!.lat!, d.lng!),
        infoWindow: const InfoWindow(title: 'Destination'),
      ));
    }
    return markers;
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        children: [
          _routeRow(
            theme,
            icon: Icons.my_location,
            label: 'Pickup',
            place: draft.pickup,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ),
          _routeRow(
            theme,
            icon: Icons.location_on,
            label: 'Destination',
            place: draft.dropoff,
          ),
        ],
      ),
    );
  }

  Widget _routeRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Place? place,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                place?.description ?? 'Not set',
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VehicleSelector extends StatelessWidget {
  const _VehicleSelector({
    required this.selectedId,
    required this.passengers,
    required this.onSelect,
  });

  final String selectedId;
  final int passengers;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // Grow the row height with the system font scale so a tall card (icon +
    // name + 2-line description) never clips at large text sizes.
    final scale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5).toDouble();
    return SizedBox(
      height: 132 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kVehicleTypes.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final v = kVehicleTypes[i];
          final disabled = v.capacity < passengers;
          return _VehicleCard(
            vehicle: v,
            selected: v.id == selectedId,
            disabled: disabled,
            onTap: disabled ? null : () => onSelect(v.id),
          );
        },
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final VehicleType vehicle;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final borderColor = selected ? scheme.primary : scheme.outline;
    final fg = disabled ? scheme.onSurface.withValues(alpha: 0.4) : null;

    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          width: 132,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.08)
                : scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : AppStroke.thin,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                _vehicleIcon(vehicle.icon),
                size: 30,
                color: selected ? scheme.primary : (fg ?? scheme.onSurface),
              ),
              const Spacer(),
              Text(
                vehicle.name,
                style: theme.textTheme.titleMedium?.copyWith(color: fg),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                vehicle.description,
                style: theme.textTheme.bodySmall?.copyWith(color: fg),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves a [VehicleType.icon] key to a Material glyph. Keeping the mapping
/// here (presentation) keeps the domain free of Material imports.
IconData _vehicleIcon(String key) => switch (key) {
      'saloon' => Icons.directions_car_outlined,
      'estate' => Icons.directions_car_filled_outlined,
      'mpv' => Icons.airport_shuttle_outlined,
      'executive' => Icons.local_taxi_outlined,
      _ => Icons.directions_car_outlined,
    };

class _ScheduleSelector extends StatelessWidget {
  const _ScheduleSelector({
    required this.scheduledFor,
    required this.onAsap,
    required this.onPick,
  });

  final DateTime? scheduledFor;
  final VoidCallback onAsap;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final isAsap = scheduledFor == null;
    return Row(
      children: [
        Expanded(
          child: _ScheduleChip(
            label: 'Now',
            selected: isAsap,
            onTap: onAsap,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: _ScheduleChip(
            icon: Icons.schedule,
            label: isAsap
                ? 'Schedule for later'
                : Fmt.dateTime(scheduledFor!),
            selected: !isAsap,
            onTap: onPick,
          ),
        ),
      ],
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.08)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: selected ? 1.5 : 0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.quoteAsync,
    required this.paymentMethod,
    required this.officePhone,
    required this.onRetry,
  });

  final AsyncValue<Quote?> quoteAsync;
  final String paymentMethod;
  final String officePhone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A genuine quote failure (network/server/no-postcode) blocks booking and
    // offers a "Call office" fallback — not just a retry row.
    return quoteAsync.when(
      loading: () => const AppCard(
        child: SizedBox(
          height: 72,
          child: LoadingView(message: 'Getting your fare…'),
        ),
      ),
      error: (err, _) => QuoteUnavailableCard(
        officePhone: officePhone,
        onRetry: onRetry,
      ),
      data: (quote) {
        if (quote == null) {
          return AppCard(
            child: _QuoteError(
              message: 'No fare yet. Set pickup and destination to get a price.',
              onRetry: onRetry,
            ),
          );
        }
        return AppCard(child: _buildFare(theme, quote));
      },
    );
  }

  Widget _buildFare(ThemeData theme, Quote quote) {
    final price =
        paymentMethod == 'account' ? quote.priceAccount : quote.priceCash;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estimated fare', style: theme.textTheme.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(Fmt.money(price), style: theme.textTheme.displayMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (quote.durationText.isNotEmpty) quote.durationText,
                  if (quote.mileageText.isNotEmpty) quote.mileageText,
                ].join('  •  '),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary),
      ],
    );
  }
}

class _QuoteError extends StatelessWidget {
  const _QuoteError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(message, style: theme.textTheme.bodySmall),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
