import 'package:freezed_annotation/freezed_annotation.dart';

part 'place.freezed.dart';
part 'place.g.dart';

/// A resolved location used across booking, tracking, activity and profile.
/// Mirrors the API's resolved-address shape (description + postcode + lat/lng).
@freezed
abstract class Place with _$Place {
  const factory Place({
    required String description,
    String? postcode,
    double? lat,
    double? lng,
    @Default('') String addressLine,
  }) = _Place;

  factory Place.fromJson(Map<String, dynamic> json) => _$PlaceFromJson(json);
}

/// A saved address (Home / Work / custom) belonging to a customer.
@freezed
abstract class SavedPlace with _$SavedPlace {
  const factory SavedPlace({
    required String id,
    required String label,
    required Place place,
  }) = _SavedPlace;

  factory SavedPlace.fromJson(Map<String, dynamic> json) =>
      _$SavedPlaceFromJson(json);
}
