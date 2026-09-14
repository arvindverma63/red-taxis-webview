import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Set true once Maps SDK keys are configured (Android manifest + iOS +
/// web index.html). Until then [MapView] renders a themed placeholder so the
/// app runs cleanly in preview/dev without a key.
const bool kMapsEnabled =
    bool.fromEnvironment('MAPS_ENABLED', defaultValue: false);

/// Shared map surface used by booking + tracking. Shows a real [GoogleMap] when
/// [kMapsEnabled], otherwise a branded placeholder. Keep map wiring in one
/// place so both features behave identically.
class MapView extends StatelessWidget {
  const MapView({
    super.key,
    this.initial,
    this.markers = const {},
    this.polylines = const {},
    this.onMapCreated,
    this.height,
  });

  final CameraPosition? initial;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController)? onMapCreated;
  final double? height;

  static const _fallbackCamera = CameraPosition(
    target: LatLng(51.0058, -2.1916), // Gillingham, Dorset (Ace heartland)
    zoom: 13,
  );

  @override
  Widget build(BuildContext context) {
    final map = kMapsEnabled
        ? GoogleMap(
            initialCameraPosition: initial ?? _fallbackCamera,
            markers: markers,
            polylines: polylines,
            onMapCreated: onMapCreated,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          )
        : const _MapPlaceholder();
    return height == null ? map : SizedBox(height: height, child: map);
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: AppColors.brand, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text('Map preview',
                style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
