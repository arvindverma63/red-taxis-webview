import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/domain/place.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../activity/application/activity_controller.dart';
import '../../activity/domain/booking_summary.dart';
import '../../booking/data/route_service.dart';
import '../application/tracking_controller.dart';
import '../domain/booking_status.dart';
import '../domain/tracking_state.dart';
import 'widgets/tracking_widgets.dart';

/// Live booking tracking, faithful to the GoRide tracking frames:
/// a full-bleed [MapView] with a floating route header and map controls, over
/// a draggable bottom sheet carrying the trip status, ETA, driver card and actions.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({
    super.key,
    required this.bookingId,
    this.initialBooking,
  });

  final String bookingId;
  final BookingSummary? initialBooking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for live status transitions to refresh global activity history in background
    ref.listen<AsyncValue<TrackingState>>(trackingProvider(bookingId), (previous, next) {
      final nextStatus = next.valueOrNull?.status;
      final prevStatus = previous?.valueOrNull?.status;
      if (nextStatus != null && nextStatus != prevStatus) {
        ref.read(activityControllerProvider.notifier).refresh();
        ref.invalidate(bookingDetailProvider(bookingId));
      }
    });

    final async = ref.watch(trackingProvider(bookingId));

    // Resolve the full booking details (pickup, dropoff, route points, fare)
    final detailAsync = ref.watch(bookingDetailProvider(bookingId));
    final activityBookings = ref.watch(activityControllerProvider).valueOrNull;

    BookingSummary? booking;
    if (activityBookings != null) {
      for (final b in activityBookings) {
        if (b.id == bookingId) {
          booking = b;
          break;
        }
      }
      if (booking == null && activityBookings.isNotEmpty) {
        final ongoing = activityBookings.where((b) => b.isActive).toList();
        if (ongoing.isNotEmpty) {
          booking = ongoing.first;
        }
      }
    }
    booking ??= detailAsync.valueOrNull ?? initialBooking;

    // Synchronize booking status with live tracking state if available
    if (booking != null && async.hasValue) {
      final liveStatus = async.requireValue.status.name;
      if (booking.status != liveStatus) {
        booking = booking.copyWith(status: liveStatus);
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: async.when(
        loading: () => const LoadingView(message: 'Connecting to your trip…'),
        error: (err, _) => ErrorView(
          message: 'We lost the connection to your trip.\n$err',
          onRetry: () => ref.invalidate(trackingProvider(bookingId)),
        ),
        data: (state) => _TrackingBody(
          state: state,
          booking: booking,
        ),
      ),
    );
  }
}

class _TrackingBody extends StatefulWidget {
  const _TrackingBody({
    required this.state,
    this.booking,
  });

  final TrackingState state;
  final BookingSummary? booking;

  @override
  State<_TrackingBody> createState() => _TrackingBodyState();
}

class _TrackingBodyState extends State<_TrackingBody> {
  GoogleMapController? _mapController;
  List<LatLng> _routePoints = const [];
  Place? _resolvedPickup;
  Place? _resolvedDropoff;
  String? _lastRouteKey;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void didUpdateWidget(covariant _TrackingBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking?.id != widget.booking?.id ||
        oldWidget.booking?.pickup != widget.booking?.pickup ||
        oldWidget.booking?.dropoff != widget.booking?.dropoff) {
      _loadRoute();
    }
  }

  Future<void> _loadRoute() async {
    const routeService = RouteService();
    final p = widget.booking?.pickup != null
        ? routeService.resolvePlaceDetails(widget.booking!.pickup)
        : routeService.resolvePlaceDetails(const Place(
            description: 'Gillingham Station, Station Road',
            postcode: 'SP8 4QF',
            lat: 51.0382,
            lng: -2.2718,
          ));
    final d = widget.booking?.dropoff != null
        ? routeService.resolvePlaceDetails(widget.booking!.dropoff)
        : routeService.resolvePlaceDetails(const Place(
            description: 'Shaftesbury, High Street',
            postcode: 'SP7 8JE',
            lat: 51.0058,
            lng: -2.1972,
          ));

    final start = LatLng(p.lat ?? 51.0382, p.lng ?? -2.2718);
    final end = LatLng(d.lat ?? 51.0058, d.lng ?? -2.1972);

    final key =
        '${start.latitude},${start.longitude}->${end.latitude},${end.longitude}';
    if (_lastRouteKey == key && _routePoints.isNotEmpty) {
      return;
    }
    _lastRouteKey = key;

    if (mounted) {
      setState(() {
        _resolvedPickup = p;
        _resolvedDropoff = d;
      });
    }

    final routeData = await routeService.fetchRoute(start, end);
    if (!mounted) return;

    setState(() {
      _routePoints = routeData.points;
    });

    _fitMapBounds();
  }

  void _fitMapBounds() {
    if (_mapController == null) return;

    final points = <LatLng>[
      if (_routePoints.isNotEmpty) ..._routePoints,
      if (_resolvedPickup?.lat != null && _resolvedPickup?.lng != null)
        LatLng(_resolvedPickup!.lat!, _resolvedPickup!.lng!),
      if (_resolvedDropoff?.lat != null && _resolvedDropoff?.lng != null)
        LatLng(_resolvedDropoff!.lat!, _resolvedDropoff!.lng!),
      if (widget.state.driver != null)
        LatLng(widget.state.driver!.lat, widget.state.driver!.lng),
    ];

    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final pt in points) {
      if (pt.latitude < minLat) minLat = pt.latitude;
      if (pt.latitude > maxLat) maxLat = pt.latitude;
      if (pt.longitude < minLng) minLng = pt.longitude;
      if (pt.longitude > maxLng) maxLng = pt.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    // Padding ensures pins and route line don't get cut off by header and bottom sheet
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 72),
    );
  }

  Set<Marker> _buildMarkers(DriverInfo? driver) {
    final markers = <Marker>{};

    if (_resolvedPickup?.lat != null && _resolvedPickup?.lng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(_resolvedPickup!.lat!, _resolvedPickup!.lng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Pickup',
          snippet: _resolvedPickup!.description.isNotEmpty
              ? _resolvedPickup!.description
              : _resolvedPickup!.addressLine,
        ),
      ));
    }

    if (_resolvedDropoff?.lat != null && _resolvedDropoff?.lng != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(_resolvedDropoff!.lat!, _resolvedDropoff!.lng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destination',
          snippet: _resolvedDropoff!.description.isNotEmpty
              ? _resolvedDropoff!.description
              : _resolvedDropoff!.addressLine,
        ),
      ));
    }

    if (driver != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(driver.lat, driver.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: driver.name,
          snippet: '${driver.vehicle} · ${driver.plate}',
        ),
      ));
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(DriverInfo? driver) {
    final polylines = <Polyline>{};

    // 1. Primary trip route polyline (Brand Red, 5px, rounded)
    if (_routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('trip_route'),
          points: _routePoints,
          color: const Color(0xFFFE2020), // First Taxis Brand Red
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    // 2. Driver en-route polyline (Azure dashed)
    if (driver != null &&
        _resolvedPickup?.lat != null &&
        _resolvedPickup?.lng != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('driver_route'),
          points: [
            LatLng(driver.lat, driver.lng),
            LatLng(_resolvedPickup!.lat!, _resolvedPickup!.lng!),
          ],
          color: const Color(0xFF2E90FA),
          width: 3,
          patterns: [PatternItem.dash(12), PatternItem.gap(6)],
        ),
      );
    }

    return polylines;
  }

  String get _pickupLabel {
    final b = widget.booking;
    if (b != null) {
      if (b.pickup.addressLine.trim().isNotEmpty) {
        return b.pickup.addressLine.trim();
      }
      if (b.pickup.description.trim().isNotEmpty) {
        return b.pickup.description.trim();
      }
    }
    if (_resolvedPickup != null) {
      if (_resolvedPickup!.addressLine.trim().isNotEmpty) {
        return _resolvedPickup!.addressLine.trim();
      }
      if (_resolvedPickup!.description.trim().isNotEmpty) {
        return _resolvedPickup!.description.trim();
      }
    }
    return 'Pickup point';
  }

  String get _destinationLabel {
    final b = widget.booking;
    if (b != null) {
      if (b.dropoff.addressLine.trim().isNotEmpty) {
        return b.dropoff.addressLine.trim();
      }
      if (b.dropoff.description.trim().isNotEmpty) {
        return b.dropoff.description.trim();
      }
    }
    if (_resolvedDropoff != null) {
      if (_resolvedDropoff!.addressLine.trim().isNotEmpty) {
        return _resolvedDropoff!.addressLine.trim();
      }
      if (_resolvedDropoff!.description.trim().isNotEmpty) {
        return _resolvedDropoff!.description.trim();
      }
    }
    return 'Destination';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.status.isCancelled) {
      return const _TerminalState(
        icon: Icons.cancel_outlined,
        kind: StatusKind.danger,
        title: 'Booking cancelled',
        subtitle: 'This booking is no longer active.',
        showBackHome: true,
      );
    }
    if (widget.state.status.isComplete) {
      return _CompletedState(
        state: widget.state,
        booking: widget.booking,
      );
    }

    final driver = widget.state.status.hasDriver ? widget.state.driver : null;

    final initialCamera = CameraPosition(
      target: _resolvedPickup?.lat != null && _resolvedPickup?.lng != null
          ? LatLng(_resolvedPickup!.lat!, _resolvedPickup!.lng!)
          : const LatLng(51.0058, -2.1916),
      zoom: 13,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: MapView(
            initial: initialCamera,
            markers: _buildMarkers(driver),
            polylines: _buildPolylines(driver),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_routePoints.isNotEmpty) {
                _fitMapBounds();
              }
            },
          ),
        ),
        // Floating route header + map controls, inset under the status bar.
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                RouteHeader(
                  pickup: _pickupLabel,
                  destination: _destinationLabel,
                  onToggleDetail: _fitMapBounds,
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
            onTap: _fitMapBounds,
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
        _StatusSheet(
          state: widget.state,
          booking: widget.booking,
        ),
      ],
    );
  }
}

// ── Draggable status sheet ─────────────────────────────────────────────────

class _StatusSheet extends StatelessWidget {
  const _StatusSheet({
    required this.state,
    this.booking,
  });

  final TrackingState state;
  final BookingSummary? booking;

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
                _ActionButtons(
                  hasDriver: state.status.hasDriver,
                  bookingId: state.bookingId,
                ),
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
  const _ActionButtons({
    required this.hasDriver,
    required this.bookingId,
  });

  final bool hasDriver;
  final String bookingId;

  void _stubCall(BuildContext context, String who) {
    // TODO(B?): wire to url_launcher tel: once support numbers land in config.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Calling $who…')));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.info_outline_rounded, size: 16),
            label: const Text('Trip Details'),
            onPressed: () =>
                context.push('${Routes.bookingDetail}/$bookingId'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppButton(
            label: 'Call office',
            icon: Icons.support_agent_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => _stubCall(context, 'the office'),
          ),
        ),
      ],
    );
  }
}

// ── Completed state (fare receipt) ─────────────────────────────────────────

class _CompletedState extends StatelessWidget {
  const _CompletedState({
    required this.state,
    this.booking,
  });

  final TrackingState state;
  final BookingSummary? booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final driver = state.driver;
    final brand = AppConfig.fromEnvironment().brandName;
    final fare = booking?.price ?? 9.50;

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
            'Thanks for riding with $brand.',
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
          FareSummary(
            lines: [
              FareLine('Trip fare', fare),
              const FareLine('Booking fee', 1.00),
              FareLine('Total', fare + 1.00, emphasised: true),
            ],
            paymentLabel: booking?.paymentMethod ?? 'Cash',
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
