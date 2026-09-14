import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/widgets.dart';
import '../application/activity_controller.dart';
import '../domain/booking_summary.dart';
import 'widgets/amend_booking_sheet.dart';
import 'widgets/fare_breakdown_card.dart';
import 'widgets/ride_details_table.dart';
import 'widgets/ride_vehicle_card.dart';
import 'widgets/route_path.dart';

/// Full "Ride Details" for one booking, matching the GoRide ride-details frames
/// (`30439:546` scheduled, `30439:548` completed, `30439:549` canceled):
/// vehicle card → route card → details table → fare card, on a soft grey
/// canvas, with status-appropriate actions pinned to the bottom.
///
/// Active trips keep Track / Request change / Cancel; scheduled-but-unengaged
/// trips additionally surface a "we'll notify you" banner; past trips offer
/// "Book again". Reached via `/activity/:bookingId`.
class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(bookingDetailProvider(bookingId));

    return detail.when(
      loading: () => const _DetailScaffold(body: LoadingView()),
      error: (error, _) => _DetailScaffold(
        body: ErrorView(
          message: error is ApiException
              ? error.message
              : 'We couldn’t load this booking.',
          onRetry: () => ref.invalidate(bookingDetailProvider(bookingId)),
        ),
      ),
      data: (booking) => _DetailBody(booking: booking),
    );
  }
}

/// Shared chrome for the ride-details screen: centred "Ride Details" title and
/// the soft grey canvas the GoRide cards float on.
class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.body, this.bottomBar});

  final Widget body;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bar = bottomBar;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text('Ride Details'),
        centerTitle: true,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: bar == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: bar,
            ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.booking});

  final BookingSummary booking;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _busy = false;

  BookingSummary get _booking => widget.booking;

  ActivityController get _controller =>
      ref.read(activityControllerProvider.notifier);

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onRequestChange() async {
    final request = await showAppBottomSheet<AmendRequest>(
      context,
      child: AmendBookingSheet(booking: _booking),
    );
    if (request == null || !request.hasChanges) return;

    setState(() => _busy = true);
    try {
      await _controller.requestChange(
        _booking.id,
        newTime: request.newTime,
        passengers: request.passengers,
      );
      _showSnack('Change request sent to the operator.');
      if (mounted) context.pop();
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Couldn’t send your change request. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onCancel() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel booking?',
      message:
          'We’ll ask the operator to cancel this trip. This can’t be undone.',
      confirmLabel: 'Cancel trip',
      cancelLabel: 'Keep booking',
      destructive: true,
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await _controller.cancel(_booking.id);
      _showSnack('Cancellation requested.');
      if (mounted) context.pop();
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Couldn’t cancel your booking. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onShareReceipt() =>
      _showSnack('Your receipt will be sent to you shortly.');

  @override
  Widget build(BuildContext context) {
    final booking = _booking;

    return _DetailScaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Awaiting-driver trips get the GoRide "we'll notify you" banner; live
          // (driver-engaged) trips don't (they show Track instead). The header
          // copy adapts: "Your Scheduled Ride" for genuinely future bookings,
          // "Your Ride" for a just-requested ASAP ("Now") booking.
          if (booking.isActive && !booking.isDriverEngaged) ...[
            _ScheduledBanner(booking: booking),
            const SizedBox(height: AppSpacing.md),
          ],
          RideVehicleCard(booking: booking),
          const SizedBox(height: AppSpacing.md),
          _RouteCard(booking: booking),
          const SizedBox(height: AppSpacing.md),
          RideDetailsTable(booking: booking),
          const SizedBox(height: AppSpacing.md),
          FareBreakdownCard(booking: booking),
        ],
      ),
      bottomBar: _BottomActions(
        booking: booking,
        busy: _busy,
        onTrack: () => context.push('${Routes.tracking}/${booking.id}'),
        onChange: _onRequestChange,
        onCancel: _onCancel,
        onShareReceipt: _onShareReceipt,
        onBookAgain: () => context.go(Routes.home),
      ),
    );
  }
}

/// The green header banner with the notify-on-allocation pill, shown for
/// awaiting-driver trips (frame `30439:546`). The title reads "Your Scheduled
/// Ride" for genuinely future bookings and "Your Ride" for an ASAP ("Now")
/// request, so an immediate booking isn't mislabelled as scheduled.
class _ScheduledBanner extends StatelessWidget {
  const _ScheduledBanner({required this.booking});

  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            booking.isScheduled ? 'Your Scheduled Ride' : 'Your Ride',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Fmt.dateTime(booking.scheduledFor),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'We’ll notify you when a driver’s found',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: AppColors.success),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The pickup → dropoff route inside a details card.
class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.booking});

  final BookingSummary booking;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: RoutePath(
        pickup: booking.pickup,
        dropoff: booking.dropoff,
        showPostcodes: true,
      ),
    );
  }
}

/// The status-appropriate action bar pinned to the bottom of the screen.
class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.booking,
    required this.busy,
    required this.onTrack,
    required this.onChange,
    required this.onCancel,
    required this.onShareReceipt,
    required this.onBookAgain,
  });

  final BookingSummary booking;
  final bool busy;
  final VoidCallback onTrack;
  final VoidCallback onChange;
  final VoidCallback onCancel;
  final VoidCallback onShareReceipt;
  final VoidCallback onBookAgain;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Live, driver-engaged trip → Track + change/cancel (frame parity with the
    // tracking entry point).
    if (booking.isActive && booking.isDriverEngaged) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: 'Track driver',
            icon: Icons.my_location,
            onPressed: onTrack,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Request change',
                  variant: AppButtonVariant.secondary,
                  onPressed: onChange,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.text,
                  onPressed: onCancel,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Scheduled (awaiting driver) → Cancel Ride only. No "Share receipt" here:
    // the trip hasn't happened yet, so there's no receipt to share (a receipt
    // only exists once the booking is completed, handled below).
    if (booking.isActive) {
      return AppButton(
        label: 'Cancel ride',
        variant: AppButtonVariant.text,
        onPressed: onCancel,
      );
    }

    // Completed → Share Receipt + Book again. Canceled → Book again only.
    if (booking.isCompleted) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: 'Share receipt',
            variant: AppButtonVariant.secondary,
            onPressed: onShareReceipt,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Book again',
            icon: Icons.refresh,
            onPressed: onBookAgain,
          ),
        ],
      );
    }

    return AppButton(
      label: 'Book again',
      icon: Icons.refresh,
      onPressed: onBookAgain,
    );
  }
}
