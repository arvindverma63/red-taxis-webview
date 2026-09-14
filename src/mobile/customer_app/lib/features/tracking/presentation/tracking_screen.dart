import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../application/tracking_controller.dart';
import '../domain/booking_status.dart';
import '../domain/tracking_state.dart';
import 'widgets/tracking_widgets.dart';

// Pickup point the mock driver heads toward — matches the repository's
// constants so the marker and pickup pin converge on the same spot.
const double _kPickupLat = 51.0058;
const double _kPickupLng = -2.1916;

// Mock route endpoints surfaced in the route header. Real pickup/destination
// strings arrive on [TrackingState] once the booking detail is wired (PRD B4).
const String _kPickupLabel = 'Pickup point';
const String _kDestinationLabel = 'Destination';

/// Live booking tracking, faithful to the GoRide tracking frames
/// (`30439:403/404`, `30431:30716`, `30431:30709`): a full-bleed [MapView]
/// with a floating route header and map controls, over a draggable bottom
/// sheet carrying the trip status, ETA, driver card and actions. Terminal
/// states (completed with a fare receipt, cancelled) replace the live layout.
///
/// Drives entirely off [trackingProvider] for [bookingId]; no business logic
/// lives here.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trackingProvider(bookingId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: async.when(
        loading: () => const LoadingView(message: 'Connecting to your trip…'),
        error: (err, _) => ErrorView(
          message: 'We lost the connection to your trip.\n$err',
          onRetry: () => ref.invalidate(trackingProvider(bookingId)),
        ),
        data: (state) => _TrackingBody(state: state),
      ),
    );
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.state});

  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    if (state.status.isCancelled) {
      return const _TerminalState(
        icon: Icons.cancel_outlined,
        kind: StatusKind.danger,
        title: 'Booking cancelled',
        subtitle: 'This booking is no longer active.',
        showBackHome: true,
      );
    }
    if (state.status.isComplete) {
      return _CompletedState(state: state);
    }

    final driver = state.status.hasDriver ? state.driver : null;

    // Map fills the screen; the route header + controls float over its top,
    // and the status sheet is draggable over the bottom (GoRide layout).
    return Stack(
      children: [
        Positioned.fill(child: _TrackingMap(driver: driver)),
        // Floating route header + map controls, inset under the status bar.
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const RouteHeader(
                  pickup: _kPickupLabel,
                  destination: _kDestinationLabel,
                ),
              ],
            ),
          ),
        ),
        // Recenter control floats above the sheet, bottom-right.
        Positioned(
          right: AppSpacing.lg,
          bottom: MediaQuery.sizeOf(context).height * 0.42 + AppSpacing.lg,
          child: MapFab(
            icon: Icons.my_location,
            tooltip: 'Recenter',
            onTap: () {},
          ),
        ),
        // Back control floats bottom-left, symmetric with recenter.
        Positioned(
          left: AppSpacing.lg,
          bottom: MediaQuery.sizeOf(context).height * 0.42 + AppSpacing.lg,
          child: MapFab(
            icon: Icons.arrow_back_ios_new,
            tooltip: 'Back',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        _StatusSheet(state: state),
      ],
    );
  }
}

// ── Map ──────────────────────────────────────────────────────────────────

class _TrackingMap extends StatelessWidget {
  const _TrackingMap({required this.driver});

  final DriverInfo? driver;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      const Marker(
        markerId: MarkerId('pickup'),
        position: LatLng(_kPickupLat, _kPickupLng),
        infoWindow: InfoWindow(title: 'Pickup'),
      ),
      if (driver != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driver!.lat, driver!.lng),
          infoWindow: InfoWindow(title: driver!.name),
        ),
    };

    // Draw the driver→pickup route line when both ends are known.
    final polylines = <Polyline>{
      if (driver != null)
        Polyline(
          polylineId: const PolylineId('route'),
          color: AppColors.brand,
          width: 4,
          points: [
            LatLng(driver!.lat, driver!.lng),
            const LatLng(_kPickupLat, _kPickupLng),
          ],
        ),
    };

    return MapView(
      initial: const CameraPosition(
        target: LatLng(_kPickupLat, _kPickupLng),
        zoom: 14,
      ),
      markers: markers,
      polylines: polylines,
    );
  }
}

// ── Draggable status sheet ─────────────────────────────────────────────────

class _StatusSheet extends StatelessWidget {
  const _StatusSheet({required this.state});

  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      // Collapsed snap shows headline + driver row (frame 403); expanded snap
      // reveals the full status timeline (frame 404).
      initialChildSize: 0.42,
      minChildSize: 0.42,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.42, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neutral900.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: [
                const _SheetGrabber(),
                const SizedBox(height: AppSpacing.lg),
                _SheetHeadline(state: state),
                if (_etaCopy(state) != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _etaCopy(state)!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (state.driver != null && state.status.hasDriver) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _VehicleLine(driver: state.driver!),
                  const SizedBox(height: AppSpacing.lg),
                  Divider(
                    height: AppStroke.thin,
                    thickness: AppStroke.thin,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DriverCard(
                    name: state.driver!.name,
                    rating: 4.8,
                    colorValue: state.driver!.colorValue,
                    onMessage: () => _stubCall(context, state.driver!.name),
                    onCall: () => _stubCall(context, state.driver!.name),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                StatusTimeline(current: state.status),
                const SizedBox(height: AppSpacing.xl),
                _ActionButtons(hasDriver: state.status.hasDriver),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _stubCall(BuildContext context, String who) {
    // TODO(B?): wire to url_launcher tel: once support numbers land in config.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Contacting $who…')));
  }

  static String? _etaCopy(TrackingState s) {
    final eta = s.etaMinutes;
    return switch (s.status) {
      BookingStatus.requested => 'Waiting for an operator to confirm.',
      BookingStatus.confirmed => 'Finding you a driver…',
      BookingStatus.allocated when eta != null =>
        'Driver arriving in about $eta min.',
      BookingStatus.allocated => 'Driver arriving shortly.',
      BookingStatus.arriving when eta != null && eta > 1 =>
        'Driver arriving in $eta min.',
      BookingStatus.arriving => 'Driver arriving in 1 min.',
      BookingStatus.arrived => 'Please make your way to the pickup point.',
      BookingStatus.inProgress => 'You’re on your way.',
      _ => null,
    };
  }
}

class _SheetHeadline extends StatelessWidget {
  const _SheetHeadline({required this.state});

  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = state.status;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            _headline(state),
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        StatusChip(label: status.label, kind: status.statusKind),
      ],
    );
  }

  static String _headline(TrackingState s) => switch (s.status) {
        BookingStatus.requested => 'Sending your request…',
        BookingStatus.confirmed => 'Booking confirmed',
        BookingStatus.allocated => 'Driver assigned',
        BookingStatus.arriving => 'Driver is heading to your location…',
        BookingStatus.arrived => 'Your driver has arrived',
        BookingStatus.inProgress => 'Enjoy your trip',
        BookingStatus.completed => 'Trip complete',
        BookingStatus.cancelled => 'Booking cancelled',
      };
}

/// "Toyota Prius · White · AC21 TXI" style vehicle line under the headline,
/// matching the GoRide frame's vehicle row.
class _VehicleLine extends StatelessWidget {
  const _VehicleLine({required this.driver});

  final DriverInfo driver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.local_taxi_outlined,
            size: 16, color: theme.colorScheme.onSurface),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '${driver.vehicle}  ·  ${driver.plate}',
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outline,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

// ── Actions ────────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.hasDriver});

  final bool hasDriver;

  void _stubCall(BuildContext context, String who) {
    // TODO(B?): wire to url_launcher tel: once support numbers land in config.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Calling $who…')));
  }

  @override
  Widget build(BuildContext context) {
    // Driver-facing contact lives in the DriverCard's circular actions, so the
    // sheet's primary CTA is always "Call office" (operator support line).
    return AppButton(
      label: 'Call office',
      icon: Icons.support_agent_outlined,
      variant: AppButtonVariant.secondary,
      onPressed: () => _stubCall(context, 'the office'),
    );
  }
}

// ── Completed state (fare receipt) ─────────────────────────────────────────

class _CompletedState extends StatelessWidget {
  const _CompletedState({required this.state});

  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final driver = state.driver;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 56, color: AppColors.success),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Trip complete',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Thanks for riding with Ace Taxis.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (driver != null) ...[
            AppCard(
              child: DriverCard(
                name: driver.name,
                rating: 4.8,
                colorValue: driver.colorValue,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Fare breakdown. Amounts are placeholders until the booking quote is
          // surfaced on TrackingState (PRD B4 — fare/receipt wiring); the
          // component is shaped so wiring is a data swap, not a layout change.
          const FareSummary(
            lines: [
              FareLine('Trip fare', 9.50),
              FareLine('Booking fee', 1.00),
              FareLine('Total', 10.50, emphasised: true),
            ],
            paymentLabel: 'Cash',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Back to home',
            icon: Icons.home_outlined,
            onPressed: () => context.go(Routes.home),
          ),
        ],
      ),
    );
  }
}

// ── Terminal state (cancelled) ─────────────────────────────────────────────

class _TerminalState extends StatelessWidget {
  const _TerminalState({
    required this.icon,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.showBackHome = false,
  });

  final IconData icon;
  final StatusKind kind;
  final String title;
  final String subtitle;
  final bool showBackHome;

  Color _accent() => switch (kind) {
        StatusKind.success => AppColors.success,
        StatusKind.danger => AppColors.error,
        StatusKind.active => AppColors.info,
        StatusKind.pending => AppColors.warning,
        StatusKind.neutral => AppColors.neutral400,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accent();
    return SafeArea(
      child: AdaptiveCenter(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 56, color: accent),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                title,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (showBackHome) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Back to home',
                  icon: Icons.home_outlined,
                  onPressed: () => context.go(Routes.home),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
