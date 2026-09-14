// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'place.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Place {

 String get description; String? get postcode; double? get lat; double? get lng; String get addressLine;
/// Create a copy of Place
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlaceCopyWith<Place> get copyWith => _$PlaceCopyWithImpl<Place>(this as Place, _$identity);

  /// Serializes this Place to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Place&&(identical(other.description, description) || other.description == description)&&(identical(other.postcode, postcode) || other.postcode == postcode)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.addressLine, addressLine) || other.addressLine == addressLine));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,description,postcode,lat,lng,addressLine);

@override
String toString() {
  return 'Place(description: $description, postcode: $postcode, lat: $lat, lng: $lng, addressLine: $addressLine)';
}


}

/// @nodoc
abstract mixin class $PlaceCopyWith<$Res>  {
  factory $PlaceCopyWith(Place value, $Res Function(Place) _then) = _$PlaceCopyWithImpl;
@useResult
$Res call({
 String description, String? postcode, double? lat, double? lng, String addressLine
});




}
/// @nodoc
class _$PlaceCopyWithImpl<$Res>
    implements $PlaceCopyWith<$Res> {
  _$PlaceCopyWithImpl(this._self, this._then);

  final Place _self;
  final $Res Function(Place) _then;

/// Create a copy of Place
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? description = null,Object? postcode = freezed,Object? lat = freezed,Object? lng = freezed,Object? addressLine = null,}) {
  return _then(_self.copyWith(
description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,postcode: freezed == postcode ? _self.postcode : postcode // ignore: cast_nullable_to_non_nullable
as String?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,addressLine: null == addressLine ? _self.addressLine : addressLine // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _Place implements Place {
  const _Place({required this.description, this.postcode, this.lat, this.lng, this.addressLine = ''});
  factory _Place.fromJson(Map<String, dynamic> json) => _$PlaceFromJson(json);

@override final  String description;
@override final  String? postcode;
@override final  double? lat;
@override final  double? lng;
@override@JsonKey() final  String addressLine;

/// Create a copy of Place
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlaceCopyWith<_Place> get copyWith => __$PlaceCopyWithImpl<_Place>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlaceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Place&&(identical(other.description, description) || other.description == description)&&(identical(other.postcode, postcode) || other.postcode == postcode)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.addressLine, addressLine) || other.addressLine == addressLine));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,description,postcode,lat,lng,addressLine);

@override
String toString() {
  return 'Place(description: $description, postcode: $postcode, lat: $lat, lng: $lng, addressLine: $addressLine)';
}


}

/// @nodoc
abstract mixin class _$PlaceCopyWith<$Res> implements $PlaceCopyWith<$Res> {
  factory _$PlaceCopyWith(_Place value, $Res Function(_Place) _then) = __$PlaceCopyWithImpl;
@override @useResult
$Res call({
 String description, String? postcode, double? lat, double? lng, String addressLine
});




}
/// @nodoc
class __$PlaceCopyWithImpl<$Res>
    implements _$PlaceCopyWith<$Res> {
  __$PlaceCopyWithImpl(this._self, this._then);

  final _Place _self;
  final $Res Function(_Place) _then;

/// Create a copy of Place
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? description = null,Object? postcode = freezed,Object? lat = freezed,Object? lng = freezed,Object? addressLine = null,}) {
  return _then(_Place(
description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,postcode: freezed == postcode ? _self.postcode : postcode // ignore: cast_nullable_to_non_nullable
as String?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,addressLine: null == addressLine ? _self.addressLine : addressLine // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SavedPlace {

 String get id; String get label; Place get place;
/// Create a copy of SavedPlace
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedPlaceCopyWith<SavedPlace> get copyWith => _$SavedPlaceCopyWithImpl<SavedPlace>(this as SavedPlace, _$identity);

  /// Serializes this SavedPlace to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedPlace&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.place, place) || other.place == place));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,place);

@override
String toString() {
  return 'SavedPlace(id: $id, label: $label, place: $place)';
}


}

/// @nodoc
abstract mixin class $SavedPlaceCopyWith<$Res>  {
  factory $SavedPlaceCopyWith(SavedPlace value, $Res Function(SavedPlace) _then) = _$SavedPlaceCopyWithImpl;
@useResult
$Res call({
 String id, String label, Place place
});


$PlaceCopyWith<$Res> get place;

}
/// @nodoc
class _$SavedPlaceCopyWithImpl<$Res>
    implements $SavedPlaceCopyWith<$Res> {
  _$SavedPlaceCopyWithImpl(this._self, this._then);

  final SavedPlace _self;
  final $Res Function(SavedPlace) _then;

/// Create a copy of SavedPlace
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? place = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,place: null == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as Place,
  ));
}
/// Create a copy of SavedPlace
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceCopyWith<$Res> get place {
  
  return $PlaceCopyWith<$Res>(_self.place, (value) {
    return _then(_self.copyWith(place: value));
  });
}
}


/// @nodoc
@JsonSerializable()

class _SavedPlace implements SavedPlace {
  const _SavedPlace({required this.id, required this.label, required this.place});
  factory _SavedPlace.fromJson(Map<String, dynamic> json) => _$SavedPlaceFromJson(json);

@override final  String id;
@override final  String label;
@override final  Place place;

/// Create a copy of SavedPlace
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedPlaceCopyWith<_SavedPlace> get copyWith => __$SavedPlaceCopyWithImpl<_SavedPlace>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SavedPlaceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedPlace&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.place, place) || other.place == place));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,place);

@override
String toString() {
  return 'SavedPlace(id: $id, label: $label, place: $place)';
}


}

/// @nodoc
abstract mixin class _$SavedPlaceCopyWith<$Res> implements $SavedPlaceCopyWith<$Res> {
  factory _$SavedPlaceCopyWith(_SavedPlace value, $Res Function(_SavedPlace) _then) = __$SavedPlaceCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, Place place
});


@override $PlaceCopyWith<$Res> get place;

}
/// @nodoc
class __$SavedPlaceCopyWithImpl<$Res>
    implements _$SavedPlaceCopyWith<$Res> {
  __$SavedPlaceCopyWithImpl(this._self, this._then);

  final _SavedPlace _self;
  final $Res Function(_SavedPlace) _then;

/// Create a copy of SavedPlace
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? place = null,}) {
  return _then(_SavedPlace(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,place: null == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as Place,
  ));
}

/// Create a copy of SavedPlace
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceCopyWith<$Res> get place {
  
  return $PlaceCopyWith<$Res>(_self.place, (value) {
    return _then(_self.copyWith(place: value));
  });
}
}

// dart format on
