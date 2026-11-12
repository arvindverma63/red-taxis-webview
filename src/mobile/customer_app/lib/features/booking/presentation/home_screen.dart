import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/place.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/reverse_geocoder.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../activity/application/activity_controller.dart';
import '../application/booking_draft_controller.dart';
import '../domain/booking_draft.dart';
import '../domain/vehicle_type.dart';
import 'booking_routes.dart';
import 'widgets/home_drawer.dart';

/// Home: a full-screen map with the booking sheet on top. Pick a vehicle, say
/// when, set pickup and drop-off (search, current location or map pin), then
/// continue to the review step. The hamburger opens the account drawer.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _fallbackCenter = LatLng(51.0382, -2.2718); // Gillingham

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _map;
  bool _locating = false;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  void _moveCameraTo(Place? place) {
    if (place?.lat == null || place?.lng == null) return;
    _map?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(place!.lat!, place.lng!), 15),
    );
  }

  Set<Marker> _markers(Place? pickup, Place? dropoff) {
    Marker? marker(String id, Place? p, double hue) {
      if (p?.lat == null || p?.lng == null) return null;
      return Marker(
        markerId: MarkerId(id),
        position: LatLng(p!.lat!, p.lng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      );
    }

    final pickupMarker = marker('pickup', pickup, BitmapDescriptor.hueGreen);
    final dropoffMarker = marker('dropoff', dropoff, BitmapDescriptor.hueRed);
    return {
      if (pickupMarker != null) pickupMarker,
      if (dropoffMarker != null) dropoffMarker,
    };
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (picked.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a time in the future.')),
      );
      return;
    }
    ref.read(bookingDraftProvider.notifier).setSchedule(picked);
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    try {
      final result = await ref.read(locationServiceProvider).currentPosition();
      if (!mounted) return;
      if (!result.isGranted) {
        final blocked = result.status == LocationStatus.deniedForever;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              blocked
                  ? 'Location is turned off for First Taxis. Enable it in Settings, or enter your pickup address.'
                  : 'Location is unavailable. Enter your pickup address instead.',
            ),
            action: blocked
                ? SnackBarAction(
                    label: 'Settings',
                    onPressed: () =>
                        ref.read(locationServiceProvider).openSettings(),
                  )
                : null,
          ),
        );
        return;
      }
      final pos = result.position!;
      final place = await reverseGeocode(pos.latitude, pos.longitude) ??
          Place(
            description: 'Current location',
            addressLine:
                '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
            lat: pos.latitude,
            lng: pos.longitude,
          );
      if (!mounted) return;
      ref.read(bookingDraftProvider.notifier).setPickup(place);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _continue() {
    final draft = ref.read(bookingDraftProvider);
    if (draft.pickup == null) {
      context.push(Routes.addressSearch, extra: 'pickup');
    } else if (draft.dropoff == null) {
      context.push(Routes.addressSearch, extra: 'dropoff');
    } else {
      context.push(Routes.bookingReview);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final ongoing = ref.watch(ongoingBookingsProvider);
    final theme = Theme.of(context);

    ref.listen(bookingDraftProvider.select((d) => d.pickup), (prev, next) {
      if (next != null && next != prev) _moveCameraTo(next);
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: const HomeDrawer(),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              initial: const CameraPosition(target: _fallbackCenter, zoom: 13),
              markers: _markers(draft.pickup, draft.dropoff),
              onMapCreated: (c) {
                _map = c;
                _moveCameraTo(draft.pickup);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black),
                      tooltip: 'Menu',
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (ongoing.isNotEmpty)
                    Expanded(
                      child: _ActiveRidePill(
                        onTap: () => context.push(
                          '${Routes.tracking}/${ongoing.first.id}',
                          extra: ongoing.first,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BookingSheet(
              draft: draft,
              locating: _locating,
              onVehicle: (id) =>
                  ref.read(bookingDraftProvider.notifier).setVehicle(id),
              onNow: () =>
                  ref.read(bookingDraftProvider.notifier).setSchedule(null),
              onLater: _pickSchedule,
              onEditPickup: () =>
                  context.push(Routes.addressSearch, extra: 'pickup'),
              onEditDropoff: () =>
                  context.push(Routes.addressSearch, extra: 'dropoff'),
              onCurrentLocation: _useCurrentLocation,
              onChooseOnMap: () => context.push(
                kPickOnMapPath,
                extra: draft.pickup == null ? 'pickup' : 'dropoff',
              ),
              onContinue: _continue,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRidePill extends StatelessWidget {
  const _ActiveRidePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_taxi, size: 18, color: Colors.black),
                SizedBox(width: 8),
                Text(
                  'Ride in progress · Track',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingSheet extends StatelessWidget {
  const _BookingSheet({
    required this.draft,
    required this.locating,
    required this.onVehicle,
    required this.onNow,
    required this.onLater,
    required this.onEditPickup,
    required this.onEditDropoff,
    required this.onCurrentLocation,
    required this.onChooseOnMap,
    required this.onContinue,
    required this.theme,
  });

  final BookingDraft draft;
  final bool locating;
  final ValueChanged<String> onVehicle;
  final VoidCallback onNow;
  final VoidCallback onLater;
  final VoidCallback onEditPickup;
  final VoidCallback onEditDropoff;
  final VoidCallback onCurrentLocation;
  final VoidCallback onChooseOnMap;
  final VoidCallback onContinue;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Place? pickup = draft.pickup;
    final Place? dropoff = draft.dropoff;
    final DateTime? scheduled = draft.scheduledFor;
    final String vehicleId = draft.vehicleId;

    final title = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vehicle', style: title),
              const SizedBox(height: 10),
              SizedBox(
                height: 96,
                child: Row(
                  children: [
                    for (final v in kVehicleTypes)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: v == kVehicleTypes.last ? 0 : 8,
                          ),
                          child: _VehicleCard(
                            vehicle: v,
                            selected: v.id == vehicleId,
                            onTap: () => onVehicle(v.id),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('When', style: title),
              const SizedBox(height: 10),
              _Segmented(
                children: [
                  _SegmentItem(
                    icon: Icons.bolt,
                    label: 'Now',
                    selected: scheduled == null,
                    onTap: onNow,
                  ),
                  _SegmentItem(
                    icon: Icons.calendar_today_outlined,
                    label: scheduled == null
                        ? 'Schedule for Later'
                        : DateFormat('EEE d MMM, HH:mm').format(scheduled),
                    selected: scheduled != null,
                    onTap: onLater,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Column(
                  children: [
                    _AddressRow(
                      icon: Icons.location_on,
                      iconColor: AppColors.success,
                      label: 'Pickup',
                      value: _text(pickup, 'Where should we pick you up?'),
                      onTap: onEditPickup,
                    ),
                    Divider(height: 1, color: theme.colorScheme.outline),
                    _AddressRow(
                      icon: Icons.location_on,
                      iconColor: AppColors.error,
                      label: 'Drop-off',
                      value: _text(dropoff, 'Where are you going?'),
                      onTap: onEditDropoff,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Segmented(
                children: [
                  _SegmentItem(
                    icon: Icons.my_location,
                    label: 'Use my\nCurrent Location',
                    selected: true,
                    loading: locating,
                    onTap: onCurrentLocation,
                    small: true,
                  ),
                  _SegmentItem(
                    icon: Icons.map_outlined,
                    label: 'Choose on\nFirst Taxis Map',
                    selected: false,
                    onTap: onChooseOnMap,
                    small: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: onContinue,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Continue Booking'),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward, size: 22),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _text(Place? p, String hint) {
    if (p == null) return hint;
    final line = p.addressLine.trim();
    return line.isNotEmpty ? '${p.description}, $line' : p.description;
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final VehicleType vehicle;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (vehicle.icon) {
        'estate' => Icons.directions_car_filled_outlined,
        'mpv' => Icons.airport_shuttle_outlined,
        'executive' => Icons.directions_car_filled,
        _ => Icons.directions_car_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightAccentTint : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.brand : theme.colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 30, color: Colors.black87),
            const SizedBox(height: 4),
            Text(
              vehicle.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              vehicle.description,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8.5, height: 1.15),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [for (final c in children) Expanded(child: c)],
        ),
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.small = false,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool small;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected
        ? (small ? AppColors.lightAccentTint : AppColors.brand)
        : Colors.transparent;
    return Material(
      color: bg,
      child: InkWell(
        onTap: loading ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: small ? 8 : 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              else
                Icon(icon, size: small ? 24 : 22, color: Colors.black),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (small
                          ? theme.textTheme.labelSmall
                          : theme.textTheme.titleSmall)
                      ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 34, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 20, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }
}
