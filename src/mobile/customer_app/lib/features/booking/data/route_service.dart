import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/place.dart';
import '../domain/quote.dart';

/// Service providing road-following route geometries, coordinate & postcode
/// resolution, and intelligent metered tariff calculations.
class RouteService {
  const RouteService();

  static const _ukPostcodeRegex =
      r'\b([A-Z]{1,2}[0-9][A-Z0-9]?\s*[0-9][A-Z]{2})\b';
  static const _outwardPostcodeRegex = r'\b([A-Z]{1,2}[0-9][A-Z0-9]?)\b';

  /// UK cities & towns dictionary for fast fallback geocoding & postcode resolution.
  static const List<_UkPlaceRef> _knownLocations = [
    _UkPlaceRef('gillingham', 'SP8 4QT', 51.0382, -2.2718),
    _UkPlaceRef('shaftesbury', 'SP7 8JE', 51.0058, -2.1972),
    _UkPlaceRef('bedminster', 'BS3 4EA', 51.4414, -2.5973),
    _UkPlaceRef('bristol', 'BS1 4DJ', 51.4545, -2.5879),
    _UkPlaceRef('mere', 'BA12 6JJ', 51.0915, -2.2706),
    _UkPlaceRef('wincanton', 'BA9 9LD', 51.0557, -2.4071),
    _UkPlaceRef('sturminster', 'DT10 1AN', 50.9247, -2.3104),
    _UkPlaceRef('salisbury', 'SP2 8BJ', 51.0740, -1.7950),
    _UkPlaceRef('yeovil', 'BA21 4AT', 50.9416, -2.6321),
    _UkPlaceRef('bournemouth', 'BH1 1AA', 50.7192, -1.8808),
    _UkPlaceRef('poole', 'BH15 1NF', 50.7151, -1.9872),
    _UkPlaceRef('bath', 'BA1 1AA', 51.3811, -2.3590),
    _UkPlaceRef('dorchester', 'DT1 1RN', 50.7112, -2.4412),
    _UkPlaceRef('blandford', 'DT11 7EB', 50.8560, -2.1643),
    _UkPlaceRef('sherborne', 'DT9 3NL', 50.9489, -2.5173),
    _UkPlaceRef('heathrow', 'TW6 1EW', 51.4700, -0.4543),
    _UkPlaceRef('gatwick', 'RH6 0NP', 51.1537, -0.1821),
    _UkPlaceRef('southampton', 'SO14 7DY', 50.9097, -1.4044),
    _UkPlaceRef('swindon', 'SN1 1QN', 51.5558, -1.7797),
    _UkPlaceRef('exeter', 'EX1 1HS', 50.7184, -3.5339),
    _UkPlaceRef('taunton', 'TA1 1JD', 51.0154, -3.1042),
    _UkPlaceRef('weymouth', 'DT4 8DF', 50.6138, -2.4576),
    _UkPlaceRef('christchurch', 'BH23 1AS', 50.7352, -1.7812),
    _UkPlaceRef('frome', 'BA11 1EB', 51.2312, -2.3216),
    _UkPlaceRef('london', 'SW1A 1AA', 51.5014, -0.1419),
  ];

  /// Ensures a [Place] has non-empty postcode and valid coordinates (lat, lng).
  Place resolvePlaceDetails(Place place) {
    var postcode = place.postcode?.trim() ?? '';
    var lat = place.lat;
    var lng = place.lng;

    final fullText = '${place.description} ${place.addressLine}';

    // 1. Extract UK postcode from description or addressLine if missing
    if (postcode.isEmpty) {
      final fullMatch = RegExp(_ukPostcodeRegex, caseSensitive: false)
          .firstMatch(fullText);
      if (fullMatch != null) {
        postcode = fullMatch.group(1)!.toUpperCase().trim();
      } else {
        final outwardMatch = RegExp(_outwardPostcodeRegex, caseSensitive: false)
            .firstMatch(fullText);
        if (outwardMatch != null) {
          final outward = outwardMatch.group(1)!.toUpperCase().trim();
          // Verify it's a known UK area outward code (e.g. SP, BS, BA, DT, BH, TW, SO, SN)
          if (RegExp(r'^[A-Z]{1,2}[0-9]').hasMatch(outward)) {
            postcode = '$outward 1AA';
          }
        }
      }
    }

    // 2. Match against known locations
    final lowerText = fullText.toLowerCase();
    for (final loc in _knownLocations) {
      if (lowerText.contains(loc.keyword)) {
        postcode = postcode.isEmpty ? loc.postcode : postcode;
        lat ??= loc.lat;
        lng ??= loc.lng;
        break;
      }
    }

    // 3. If coordinates are present but postcode is still missing, infer from nearest known place
    if (postcode.isEmpty && lat != null && lng != null) {
      _UkPlaceRef? nearest;
      double minD = double.infinity;
      for (final loc in _knownLocations) {
        final d = haversineDistanceMiles(lat, lng, loc.lat, loc.lng);
        if (d < minD) {
          minD = d;
          nearest = loc;
        }
      }
      if (nearest != null) {
        postcode = nearest.postcode;
      }
    }

    // 4. Fallback defaults if completely unresolved
    if (postcode.isEmpty) {
      postcode = 'SP8 4QT'; // Gillingham default
    }
    lat ??= 51.0382;
    lng ??= -2.2718;

    return place.copyWith(
      postcode: postcode,
      lat: lat,
      lng: lng,
    );
  }

  /// Calculates Haversine great-circle distance in miles.
  static double haversineDistanceMiles(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 3958.8; // Earth radius in miles
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Fetches real road driving geometry from OSRM, with curved fallback.
  Future<RouteData> fetchRoute(LatLng origin, LatLng destination) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ),
    );

    try {
      final res = await dio.get<Map<String, dynamic>>(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );
      if (res.statusCode == 200 && res.data != null) {
        final json = res.data!;
        final routes = json['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final first = routes.first as Map<String, dynamic>;
          final geom = first['geometry'] as Map<String, dynamic>?;
          final coords = geom?['coordinates'] as List<dynamic>?;
          final distMeters = (first['distance'] as num?)?.toDouble() ?? 0;
          final durSecs = (first['duration'] as num?)?.toDouble() ?? 0;

          if (coords != null && coords.isNotEmpty) {
            final points = coords.map((c) {
              final pair = c as List<dynamic>;
              return LatLng(
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              );
            }).toList();

            final miles = distMeters / 1609.344;
            final minutes = (durSecs / 60.0).round();

            return RouteData(
              points: points,
              distanceMiles: miles,
              durationMinutes: minutes,
              mileageText: _formatMiles(miles),
              durationText: _formatDuration(minutes),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[RouteService] OSRM route fetch notice: $e, using curve fallback');
    }

    // Fallback: road-adjusted Haversine calculation + curved bezier path
    final straightMiles = haversineDistanceMiles(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    // Real roads in UK are ~28% longer than straight-line as the crow flies
    final roadMiles = math.max(1.2, straightMiles * 1.28);
    // Avg 32 mph journey speed
    final minutes = math.max(4, (roadMiles / 32.0 * 60.0).round());
    final points = _generateCurvedPath(origin, destination, 30);

    return RouteData(
      points: points,
      distanceMiles: roadMiles,
      durationMinutes: minutes,
      mileageText: _formatMiles(roadMiles),
      durationText: _formatDuration(minutes),
    );
  }

  /// Generates a realistic curved line between two coordinates.
  static List<LatLng> _generateCurvedPath(
    LatLng start,
    LatLng end,
    int segments,
  ) {
    final points = <LatLng>[];
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;
    final deltaLat = end.latitude - start.latitude;
    final deltaLng = end.longitude - start.longitude;

    // Perpendicular offset for realistic road bow
    final offsetLat = -deltaLng * 0.12;
    final offsetLng = deltaLat * 0.12;
    final ctrlLat = midLat + offsetLat;
    final ctrlLng = midLng + offsetLng;

    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final lat = (1 - t) * (1 - t) * start.latitude +
          2 * (1 - t) * t * ctrlLat +
          t * t * end.latitude;
      final lng = (1 - t) * (1 - t) * start.longitude +
          2 * (1 - t) * t * ctrlLng +
          t * t * end.longitude;
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  /// Calculates a metered tariff quote based on distance, time, and vehicle type.
  Quote calculateQuote({
    required double distanceMiles,
    required int durationMinutes,
    String vehicleId = 'saloon',
    int passengers = 1,
  }) {
    // UK First Taxis standard passenger tariff:
    // Base flag drop: £3.80 (first 1.0 mile)
    // Running rate: £2.40 / mile thereafter
    const baseDrop = 3.80;
    const ratePerMile = 2.40;
    final chargeableMiles = math.max(0.0, distanceMiles - 1.0);
    final rawCash = baseDrop + (chargeableMiles * ratePerMile);

    // Vehicle Class Multipliers:
    final multiplier = switch (vehicleId.toLowerCase()) {
      'estate' => 1.25,
      'mpv' => 1.50,
      'executive' => 1.60,
      _ => 1.00, // Saloon
    };

    // Calculate fare rounded to nearest 50p
    final calculatedFare =
        math.max(5.50, ((rawCash * multiplier) * 2.0).round() / 2.0);

    return Quote(
      priceCash: calculatedFare,
      priceAccount: calculatedFare,
      totalMileage: distanceMiles,
      totalMinutes: durationMinutes,
      mileageText: _formatMiles(distanceMiles),
      durationText: _formatDuration(durationMinutes),
    );
  }

  static String _formatMiles(double miles) =>
      '${miles.toStringAsFixed(1)} miles';

  static String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes mins';
    final hrs = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '$hrs hr' : '$hrs hr $rem mins';
  }
}

class RouteData {
  const RouteData({
    required this.points,
    required this.distanceMiles,
    required this.durationMinutes,
    required this.mileageText,
    required this.durationText,
  });

  final List<LatLng> points;
  final double distanceMiles;
  final int durationMinutes;
  final String mileageText;
  final String durationText;
}

class _UkPlaceRef {
  const _UkPlaceRef(this.keyword, this.postcode, this.lat, this.lng);
  final String keyword;
  final String postcode;
  final double lat;
  final double lng;
}
