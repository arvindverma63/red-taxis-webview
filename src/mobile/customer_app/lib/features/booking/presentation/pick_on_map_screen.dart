import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/place.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/reverse_geocoder.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/widgets.dart';
import '../application/booking_draft_controller.dart';
import 'address_search_screen.dart';
import 'widgets/widgets.dart';

/// "Set pickup location" — a full-bleed map with a fixed centre pin. The driver
/// pans the map and, when it settles, the pin position is reverse-geocoded into
/// an address shown on the confirm card ([MapPinConfirmCard]).
///
/// Confirming sets the chosen end on the draft (pickup or dropoff per [mode])
/// and routes onward exactly like the typed search flow — to review when both
/// ends are known, otherwise to pickup. The "edit" pencil returns to the typed
/// [AddressSearchScreen] for the same mode.
class PickOnMapScreen extends ConsumerStatefulWidget {
  const PickOnMapScreen({super.key, required this.mode});

  final AddressMode mode;

  @override
  ConsumerState<PickOnMapScreen> createState() => _PickOnMapScreenState();
}

class _PickOnMapScreenState extends ConsumerState<PickOnMapScreen> {
  static const _fallbackCenter = LatLng(51.0058, -2.1916);

  GoogleMapController? _controller;
  LatLng? _pendingTarget;
  late LatLng _center;
  Place? _resolved;
  bool _resolving = false;
  int _lookupId = 0;

  bool get _isPickup => widget.mode == AddressMode.pickup;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider);
    final existing = _isPickup ? draft.pickup : draft.dropoff;
    if (existing?.lat != null && existing?.lng != null) {
      _center = LatLng(existing!.lat!, existing.lng!);
      _resolved = existing;
    } else {
      _center = _fallbackCenter;
      _moveToCurrentLocation(initial: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _moveToCurrentLocation({bool initial = false}) async {
    final result = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted || !result.isGranted) {
      if (!initial && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location unavailable. Move the map to pick a spot.'),
          ),
        );
      }
      return;
    }
    final target = LatLng(
      result.position!.latitude,
      result.position!.longitude,
    );
    _center = target;
    if (_controller == null) {
      // The map is not ready yet; move there as soon as it is created.
      _pendingTarget = target;
    } else {
      await _controller!.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
    }
    _resolveCenter();
  }

  /// Reverse-geocodes the pin position once the camera stops moving.
  Future<void> _resolveCenter() async {
    final id = ++_lookupId;
    final target = _center;
    setState(() => _resolving = true);
    final place = await reverseGeocode(target.latitude, target.longitude);
    if (!mounted || id != _lookupId) return;
    setState(() {
      _resolving = false;
      _resolved =
          place ??
          Place(
            description: 'Dropped pin',
            addressLine:
                '${target.latitude.toStringAsFixed(5)}, ${target.longitude.toStringAsFixed(5)}',
            lat: target.latitude,
            lng: target.longitude,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = _resolved;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              initial: CameraPosition(target: _center, zoom: 16),
              myLocationEnabled: true,
              onMapCreated: (c) {
                _controller = c;
                final pending = _pendingTarget;
                if (pending != null) {
                  _pendingTarget = null;
                  c.moveCamera(CameraUpdate.newLatLngZoom(pending, 17));
                }
              },
              onCameraMove: (pos) => _center = pos.target,
              onCameraIdle: _resolveCenter,
            ),
          ),

          // Fixed centre pin over the map.
          const IgnorePointer(
            child: Center(
              child: Padding(
                // Lift the pin tip to the visual centre.
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(
                  Icons.location_on,
                  size: 48,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),

          // Floating back control top-left.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Align(
                alignment: Alignment.topLeft,
                child: CircleIconButton.filled(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).maybePop(),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                ),
              ),
            ),
          ),

          // Recenter control top-right.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Align(
                alignment: Alignment.topRight,
                child: CircleIconButton.filled(
                  icon: Icons.my_location,
                  onTap: _moveToCurrentLocation,
                  tooltip: 'My location',
                ),
              ),
            ),
          ),

          // Confirm card pinned to the bottom.
          Align(
            alignment: Alignment.bottomCenter,
            child: MapPinConfirmCard(
              title: _isPickup ? 'Set pickup location' : 'Set destination',
              addressTitle: _resolving
                  ? 'Finding address…'
                  : (place?.description ??
                        (_isPickup
                            ? 'Move the map to choose your pickup'
                            : 'Move the map to choose your destination')),
              addressSubtitle: place?.addressLine.isNotEmpty == true
                  ? place!.addressLine
                  : place?.postcode,
              actionLabel: 'Next',
              isLoading: _resolving,
              onAction: place == null || _resolving
                  ? null
                  : () => _confirm(context, place),
              onEdit: _editTyped,
            ),
          ),
        ],
      ),
    );
  }

  /// Advance using the pinned [place] (mirrors the typed-search routing).
  void _confirm(BuildContext context, Place place) {
    final notifier = ref.read(bookingDraftProvider.notifier);
    if (_isPickup) {
      notifier.setPickup(place);
    } else {
      notifier.setDropoff(place);
    }
    final draft = ref.read(bookingDraftProvider);
    if (draft.hasRoute) {
      context.go(Routes.bookingReview);
    } else {
      context.pushReplacement(Routes.addressSearch, extra: 'pickup');
    }
  }

  /// Fall back to typed search for this mode (also the "edit" affordance).
  void _editTyped() {
    context.pushReplacement(Routes.addressSearch, extra: widget.mode.name);
  }
}
