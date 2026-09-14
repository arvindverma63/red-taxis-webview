// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Place _$PlaceFromJson(Map<String, dynamic> json) => _Place(
  description: json['description'] as String,
  postcode: json['postcode'] as String?,
  lat: (json['lat'] as num?)?.toDouble(),
  lng: (json['lng'] as num?)?.toDouble(),
  addressLine: json['addressLine'] as String? ?? '',
);

Map<String, dynamic> _$PlaceToJson(_Place instance) => <String, dynamic>{
  'description': instance.description,
  'postcode': instance.postcode,
  'lat': instance.lat,
  'lng': instance.lng,
  'addressLine': instance.addressLine,
};

_SavedPlace _$SavedPlaceFromJson(Map<String, dynamic> json) => _SavedPlace(
  id: json['id'] as String,
  label: json['label'] as String,
  place: Place.fromJson(json['place'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SavedPlaceToJson(_SavedPlace instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'place': instance.place,
    };
