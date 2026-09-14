import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Outcome of a location lookup. Lets the UI fall back to manual address entry
/// without crashing or looping when the user has not granted location access.
enum LocationStatus {
  /// A position was obtained.
  granted,

  /// The user declined this time (can be asked again later).
  denied,

  /// The user permanently declined (must enable from system settings).
  deniedForever,

  /// Location services are switched off device-wide.
  serviceDisabled,

  /// The position lookup failed unexpectedly.
  error,
}

/// Result of [LocationService.currentPosition]: a [status] plus the [position]
/// when [LocationStatus.granted].
class LocationResult {
  const LocationResult(this.status, [this.position]);

  final LocationStatus status;
  final Position? position;

  bool get isGranted => status == LocationStatus.granted && position != null;

  /// True when access is unavailable and the user should enter their pickup
  /// address manually. Anything that is not a successful fix counts.
  bool get needsManualEntry => !isGranted;
}

/// Thin wrapper over `geolocator` that resolves the current device position and,
/// crucially, NEVER loops on a permission prompt: it requests permission at
/// most once, and any denial/disabled/error path returns a status the caller
/// can use to fall back to manual address entry.
class LocationService {
  const LocationService();

  Future<LocationResult> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Ask exactly once. We do not re-request on a second denial.
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationStatus.denied);
      }

      final position = await Geolocator.getCurrentPosition();
      return LocationResult(LocationStatus.granted, position);
    } catch (_) {
      return const LocationResult(LocationStatus.error);
    }
  }
}

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());
