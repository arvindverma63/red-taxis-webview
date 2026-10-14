import 'package:geocoding/geocoding.dart' as geo;

import '../domain/place.dart';

/// Resolves a coordinate into a [Place] using the device's own geocoder.
/// Returns null when no address could be found (offline, ocean, etc.).
Future<Place?> reverseGeocode(double lat, double lng) async {
  try {
    final marks = await geo.Geocoding().placemarkFromCoordinates(lat, lng);
    if (marks.isEmpty) return null;
    return _placeFrom(marks.first, lat, lng);
  } catch (_) {
    return null;
  }
}

Place _placeFrom(geo.Placemark m, double lat, double lng) {
  String clean(String? v) => (v ?? '').trim();
  final street = [
    clean(m.subThoroughfare),
    clean(m.thoroughfare),
  ].where((e) => e.isNotEmpty).join(' ');
  final name = clean(m.name);
  final title = street.isNotEmpty
      ? street
      : (name.isNotEmpty ? name : clean(m.locality));
  final line = <String>[
    if (clean(m.locality).isNotEmpty) clean(m.locality),
    if (clean(m.administrativeArea).isNotEmpty) clean(m.administrativeArea),
    if (clean(m.postalCode).isNotEmpty) clean(m.postalCode),
  ].join(', ');
  return Place(
    description: title.isNotEmpty ? title : 'Dropped pin',
    addressLine: line,
    postcode: clean(m.postalCode).isEmpty ? null : clean(m.postalCode),
    lat: lat,
    lng: lng,
  );
}
