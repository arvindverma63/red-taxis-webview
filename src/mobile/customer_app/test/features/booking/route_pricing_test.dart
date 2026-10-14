import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:customer_app/core/domain/place.dart';
import 'package:customer_app/features/booking/data/route_service.dart';

void main() {
  group('RouteService - UK Postcode & Coordinate Resolution', () {
    const service = RouteService();

    test('resolves Gillingham town without postcode to SP8 4QT and coordinates', () {
      const input = Place(
        description: 'Gillingham',
        addressLine: 'Gillingham, Dorset',
      );

      final resolved = service.resolvePlaceDetails(input);
      expect(resolved.postcode, 'SP8 4QT');
      expect(resolved.lat, closeTo(51.0382, 0.01));
      expect(resolved.lng, closeTo(-2.2718, 0.01));
    });

    test('resolves 4647 - BEDMINSTER, East Street, Bristol to BS3 4EA and coordinates', () {
      const input = Place(
        description: '4647 - BEDMINSTER, East Street, Bristol',
        addressLine: 'East Street, Bedminster, Bristol',
      );

      final resolved = service.resolvePlaceDetails(input);
      expect(resolved.postcode, isNotEmpty);
      expect(resolved.postcode, contains('BS3'));
      expect(resolved.lat, closeTo(51.4414, 0.05));
      expect(resolved.lng, closeTo(-2.5973, 0.05));
    });

    test('preserves existing valid postcode and coordinates', () {
      const input = Place(
        description: 'Custom Spot',
        addressLine: 'Custom Address',
        postcode: 'BA12 6JJ',
        lat: 51.0915,
        lng: -2.2706,
      );

      final resolved = service.resolvePlaceDetails(input);
      expect(resolved.postcode, 'BA12 6JJ');
      expect(resolved.lat, 51.0915);
      expect(resolved.lng, -2.2706);
    });
  });

  group('RouteService - Route & Tariff Calculation', () {
    const service = RouteService();

    test('calculates accurate distance and tariff between Gillingham and Bristol', () {
      // Gillingham (SP8 4QT) to Bristol Bedminster (BS3 4EA) is ~41 road miles
      const start = LatLng(51.0382, -2.2718);
      const end = LatLng(51.4414, -2.5973);

      final straightMiles = RouteService.haversineDistanceMiles(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );
      expect(straightMiles, greaterThan(30.0));
      expect(straightMiles, lessThan(40.0));

      // Calculate Saloon quote for 41 miles
      final saloonQuote = service.calculateQuote(
        distanceMiles: 41.0,
        durationMinutes: 75,
        vehicleId: 'saloon',
      );

      expect(saloonQuote.priceCash, greaterThan(80.0));
      expect(saloonQuote.priceCash, lessThan(120.0));
      expect(saloonQuote.totalMileage, 41.0);
      expect(saloonQuote.totalMinutes, 75);
      expect(saloonQuote.mileageText, contains('41.0 miles'));
      expect(saloonQuote.durationText, contains('1 hr 15 mins'));

      // Estate should be 25% higher than Saloon
      final estateQuote = service.calculateQuote(
        distanceMiles: 41.0,
        durationMinutes: 75,
        vehicleId: 'estate',
      );
      expect(estateQuote.priceCash, greaterThan(saloonQuote.priceCash));

      // MPV should be 50% higher than Saloon
      final mpvQuote = service.calculateQuote(
        distanceMiles: 41.0,
        durationMinutes: 75,
        vehicleId: 'mpv',
      );
      expect(mpvQuote.priceCash, greaterThan(estateQuote.priceCash));
    });
  });
}
