import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../logging/remote_logger.dart';

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

  /// The lookup in flight, shared by every caller. iOS (and geolocator) allow
  /// only one permission prompt at a time: a second concurrent request throws
  /// "permission request in progress", which used to surface as "location
  /// unavailable" on the very first booking. Callers now await the same lookup.
  static Future<LocationResult>? _inFlight;

  Future<LocationResult> currentPosition() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final lookup = _lookup().whenComplete(() => _inFlight = null);
    _inFlight = lookup;
    return lookup;
  }

  /// Opens the system settings page for this app (used when the user has
  /// permanently denied location).
  Future<bool> openSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  Future<LocationResult> _lookup() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        RemoteLogger.warn(
          'Permission',
          'Location services are OFF on this device.',
        );
        return const LocationResult(LocationStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      RemoteLogger.info(
        'Permission',
        'Location permission before prompt: ${permission.name}',
      );
      if (permission == LocationPermission.denied) {
        // Ask exactly once. We do not re-request on a second denial.
        permission = await Geolocator.requestPermission();
        RemoteLogger.info(
          'Permission',
          'Location permission after prompt: ${permission.name}',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationStatus.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationStatus.denied);
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        // A fresh fix timed out (e.g. indoors): fall back to the last known one.
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) return const LocationResult(LocationStatus.error);
      return LocationResult(LocationStatus.granted, position);
    } catch (e) {
      RemoteLogger.error('Permission', 'Location lookup failed: $e');
      return const LocationResult(LocationStatus.error);
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);
