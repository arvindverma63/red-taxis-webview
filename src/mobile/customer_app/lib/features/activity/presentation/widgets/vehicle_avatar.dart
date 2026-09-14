import 'package:flutter/material.dart';

/// The soft outlined circle holding a vehicle glyph shown at the start of every
/// GoRide activity row (frames `30439:427` / `30439:429` / `30439:431`). The
/// glyph is derived from the vehicle name so saloons/estates read as a car and
/// scooter/bike fares read as a moped, matching the kit's mixed car/scooter list.
///
/// Theme-only: ring uses `colorScheme.outline`, glyph uses `onSurface`.
class VehicleAvatar extends StatelessWidget {
  const VehicleAvatar({super.key, required this.vehicleName, this.size = 48});

  /// Vehicle/tariff name (e.g. "Saloon", "Estate", "Executive", "Scooter").
  final String vehicleName;

  /// Diameter of the circle in logical pixels.
  final double size;

  /// Picks a glyph from the vehicle name — moped for scooter/bike fares, a car
  /// otherwise.
  IconData get _glyph {
    final name = vehicleName.toLowerCase();
    if (name.contains('scooter') ||
        name.contains('moped') ||
        name.contains('bike') ||
        name.contains('cycle')) {
      return Icons.two_wheeler_outlined;
    }
    return Icons.directions_car_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outline, width: 1),
      ),
      child: Icon(_glyph, size: size * 0.46, color: scheme.onSurface),
    );
  }
}
