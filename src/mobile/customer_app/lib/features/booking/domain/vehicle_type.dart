import 'package:flutter/foundation.dart';

/// A bookable vehicle class. Pure Dart (no API, no widget imports) — the
/// operator's fleet classes are a fixed, tenant-curated list for now.
///
/// [icon] is a stable String key (not a Material codepoint) so the domain stays
/// free of `dart:ui`/Material concerns. The presentation layer maps the key to
/// an `IconData` (see `_vehicleIcon` in `booking_review_screen.dart`).
@immutable
class VehicleType {
  const VehicleType({
    required this.id,
    required this.name,
    required this.description,
    required this.capacity,
    required this.icon,
  });

  /// Stable identifier carried on the [BookingDraft] and sent with a request.
  final String id;

  /// Display name, e.g. "Saloon".
  final String name;

  /// One-line description of what this class is good for.
  final String description;

  /// Maximum passenger capacity.
  final int capacity;

  /// Icon key resolved to a Material glyph by the presentation layer.
  final String icon;
}

/// The curated, ordered fleet classes shown in the booking review screen.
const List<VehicleType> kVehicleTypes = [
  VehicleType(
    id: 'saloon',
    name: 'Saloon',
    description: 'Up to 4 passengers',
    capacity: 4,
    icon: 'saloon',
  ),
  VehicleType(
    id: 'estate',
    name: 'Estate',
    description: '4 passengers, extra luggage',
    capacity: 4,
    icon: 'estate',
  ),
  VehicleType(
    id: 'mpv',
    name: 'MPV',
    description: 'Up to 6 passengers',
    capacity: 6,
    icon: 'mpv',
  ),
  VehicleType(
    id: 'executive',
    name: 'Executive',
    description: '4 passengers, premium ride',
    capacity: 4,
    icon: 'executive',
  ),
];

/// Lookup helper — returns the matching class or the first (Saloon) default.
VehicleType vehicleById(String id) => kVehicleTypes.firstWhere(
      (v) => v.id == id,
      orElse: () => kVehicleTypes.first,
    );
