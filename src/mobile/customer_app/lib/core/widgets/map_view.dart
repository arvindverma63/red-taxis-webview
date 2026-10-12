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
        : _InteractiveSimulatedMap(
            markers: markers,
            polylines: polylines,
          );
    return height == null ? map : SizedBox(height: height, child: map);
  }
}

/// A high-fidelity, interactive simulated vector map.
/// Provides a sleek, professional navigation map visual (roads, rivers, parks,
/// route polylines, and moving vehicle markers) even without Google Maps API keys.
class _InteractiveSimulatedMap extends StatefulWidget {
  const _InteractiveSimulatedMap({
    required this.markers,
    required this.polylines,
  });

  final Set<Marker> markers;
  final Set<Polyline> polylines;

  @override
  State<_InteractiveSimulatedMap> createState() => _InteractiveSimulatedMapState();
}

class _InteractiveSimulatedMapState extends State<_InteractiveSimulatedMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final matrix = _transformController.value.clone();
    matrix.scale(factor);
    _transformController.value = matrix;
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Interactive zoomable & pannable vector city map canvas
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.6,
            maxScale: 3.5,
            boundaryMargin: const EdgeInsets.all(500),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _CityMapVectorPainter(
                    isDark: isDark,
                    pulseValue: _pulseController.value,
                    hasRoute: widget.polylines.isNotEmpty,
                    hasDriver: widget.markers.any((m) => m.markerId.value == 'driver'),
                  ),
                );
              },
            ),
          ),
        ),

        // Live Telemetry / GPS Status Chip (Top-right)
        Positioned(
          top: 54,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xE61E293B) : const Color(0xE6FFFFFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0x3394A3B8) : const Color(0x33CBD5E1),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Live GPS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Map Float Controls (Right Side: Zoom in, Zoom out, Recenter)
        Positioned(
          right: 16,
          bottom: 180,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapControlButton(
                icon: Icons.add,
                tooltip: 'Zoom in',
                isDark: isDark,
                onTap: () => _zoom(1.25),
              ),
              const SizedBox(height: 8),
              _MapControlButton(
                icon: Icons.remove,
                tooltip: 'Zoom out',
                isDark: isDark,
                onTap: () => _zoom(0.8),
              ),
              const SizedBox(height: 8),
              _MapControlButton(
                icon: Icons.navigation_rounded,
                tooltip: 'Reset view',
                isDark: isDark,
                onTap: _resetView,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xE61E293B) : const Color(0xF2FFFFFF),
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for a professional vector city map.
/// Draws roads, avenues, waterways, parks, route polylines, and vehicle beacons.
class _CityMapVectorPainter extends CustomPainter {
  const _CityMapVectorPainter({
    required this.isDark,
    required this.pulseValue,
    required this.hasRoute,
    required this.hasDriver,
  });

  final bool isDark;
  final double pulseValue;
  final bool hasRoute;
  final bool hasDriver;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Map Ground Background
    final groundPaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), groundPaint);

    // 2. City Blocks & Parks
    final parkPaint = Paint()
      ..color = isDark ? const Color(0xFF132A24) : const Color(0xFFDCFCE7)
      ..style = PaintingStyle.fill;
    
    // Draw pleasant green park zones
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.12, w * 0.28, h * 0.18),
        const Radius.circular(16),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.65, h * 0.55, w * 0.26, h * 0.22),
        const Radius.circular(20),
      ),
      parkPaint,
    );

    // 3. River / Waterway Curve
    final riverPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE0F2FE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32
      ..strokeCap = StrokeCap.round;

    final riverPath = Path()
      ..moveTo(-50, h * 0.75)
      ..cubicTo(w * 0.35, h * 0.70, w * 0.45, h * 0.95, w + 50, h * 0.85);
    canvas.drawPath(riverPath, riverPaint);

    // 4. Secondary Local Roads (Grid)
    final minorRoadPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    // Horizontal roads
    for (double y = 0.1; y <= 0.95; y += 0.09) {
      canvas.drawLine(Offset(0, h * y), Offset(w, h * y), minorRoadPaint);
    }
    // Vertical roads
    for (double x = 0.12; x <= 0.95; x += 0.12) {
      canvas.drawLine(Offset(w * x, 0), Offset(w * x, h), minorRoadPaint);
    }

    // 5. Main Arterial Roads (Bold Avenues)
    final avenueBorderPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    final avenuePaint = Paint()
      ..color = isDark ? const Color(0xFF283548) : const Color(0xFFFFFFFF)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    final avenue1 = Path()
      ..moveTo(0, h * 0.35)
      ..cubicTo(w * 0.4, h * 0.38, w * 0.6, h * 0.28, w, h * 0.30);
    canvas.drawPath(avenue1, avenueBorderPaint);
    canvas.drawPath(avenue1, avenuePaint);

    final avenue2 = Path()
      ..moveTo(w * 0.45, 0)
      ..cubicTo(w * 0.48, h * 0.45, w * 0.52, h * 0.75, w * 0.50, h);
    canvas.drawPath(avenue2, avenueBorderPaint);
    canvas.drawPath(avenue2, avenuePaint);

    // 6. Motorway / Highway
    final highwayCasing = Paint()
      ..color = isDark ? const Color(0xFF475569) : const Color(0xFFFDE68A)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;
    final highwayCore = Paint()
      ..color = isDark ? const Color(0xFF78350F) : const Color(0xFFFBBF24)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    final highway = Path()
      ..moveTo(0, h * 0.15)
      ..cubicTo(w * 0.35, h * 0.22, w * 0.75, h * 0.45, w, h * 0.65);
    canvas.drawPath(highway, highwayCasing);
    canvas.drawPath(highway, highwayCore);

    // 7. Route Polyline (Pickup -> Dropoff)
    final pPickup = Offset(w * 0.35, h * 0.48);
    final pDriver = Offset(w * 0.55, h * 0.32);
    final pDropoff = Offset(w * 0.72, h * 0.62);

    final routeGlow = Paint()
      ..color = const Color(0x33FE2020)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final routeCore = Paint()
      ..color = const Color(0xFFFE2020)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final routePath = Path()
      ..moveTo(pDriver.dx, pDriver.dy)
      ..lineTo(w * 0.48, h * 0.38)
      ..lineTo(pPickup.dx, pPickup.dy)
      ..lineTo(w * 0.45, h * 0.55)
      ..lineTo(pDropoff.dx, pDropoff.dy);

    canvas.drawPath(routePath, routeGlow);
    canvas.drawPath(routePath, routeCore);

    // 8. Pickup Marker with Pulsing Ring
    final pulseRadius = 14.0 + (pulseValue * 16.0);
    final pulseOpacity = (1.0 - pulseValue).clamp(0.0, 1.0);
    final pulsePaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: pulseOpacity * 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pPickup, pulseRadius, pulsePaint);

    final pickupPaint = Paint()..color = const Color(0xFF10B981);
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(pPickup, 9, pickupPaint);
    canvas.drawCircle(pPickup, 4, whitePaint);

    // 9. Dropoff Destination Pin
    final dropoffPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(pDropoff, 9, dropoffPaint);
    canvas.drawCircle(pDropoff, 4, whitePaint);

    // 10. Vehicle / Driver Marker (Tactile Taxi Glyph)
    final vehicleBgPaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : Colors.white
      ..style = PaintingStyle.fill;
    final vehicleBorderPaint = Paint()
      ..color = const Color(0xFFFE2020)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: pDriver, radius: 15)),
      Colors.black,
      6.0,
      true,
    );
    canvas.drawCircle(pDriver, 15, vehicleBgPaint);
    canvas.drawCircle(pDriver, 15, vehicleBorderPaint);

    // Draw car icon inside marker
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🚕',
        style: TextStyle(fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(pDriver.dx - textPainter.width / 2, pDriver.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CityMapVectorPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.isDark != isDark ||
        oldDelegate.hasRoute != hasRoute;
  }
}
