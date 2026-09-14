// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tracking_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TrackingState {

 String get bookingId; BookingStatus get status;/// Present once a driver is allocated; null beforehand.
 DriverInfo? get driver;/// Minutes until the driver reaches the pickup, when known.
 int? get etaMinutes;
/// Create a copy of TrackingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackingStateCopyWith<TrackingState> get copyWith => _$TrackingStateCopyWithImpl<TrackingState>(this as TrackingState, _$identity);

  /// Serializes this TrackingState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackingState&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.status, status) || other.status == status)&&(identical(other.driver, driver) || other.driver == driver)&&(identical(other.etaMinutes, etaMinutes) || other.etaMinutes == etaMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bookingId,status,driver,etaMinutes);

@override
String toString() {
  return 'TrackingState(bookingId: $bookingId, status: $status, driver: $driver, etaMinutes: $etaMinutes)';
}


}

/// @nodoc
abstract mixin class $TrackingStateCopyWith<$Res>  {
  factory $TrackingStateCopyWith(TrackingState value, $Res Function(TrackingState) _then) = _$TrackingStateCopyWithImpl;
@useResult
$Res call({
 String bookingId, BookingStatus status, DriverInfo? driver, int? etaMinutes
});


$DriverInfoCopyWith<$Res>? get driver;

}
/// @nodoc
class _$TrackingStateCopyWithImpl<$Res>
    implements $TrackingStateCopyWith<$Res> {
  _$TrackingStateCopyWithImpl(this._self, this._then);

  final TrackingState _self;
  final $Res Function(TrackingState) _then;

/// Create a copy of TrackingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookingId = null,Object? status = null,Object? driver = freezed,Object? etaMinutes = freezed,}) {
  return _then(_self.copyWith(
bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BookingStatus,driver: freezed == driver ? _self.driver : driver // ignore: cast_nullable_to_non_nullable
as DriverInfo?,etaMinutes: freezed == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of TrackingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DriverInfoCopyWith<$Res>? get driver {
    if (_self.driver == null) {
    return null;
  }

  return $DriverInfoCopyWith<$Res>(_self.driver!, (value) {
    return _then(_self.copyWith(driver: value));
  });
}
}


/// @nodoc
@JsonSerializable()

class _TrackingState implements TrackingState {
  const _TrackingState({required this.bookingId, required this.status, this.driver, this.etaMinutes});
  factory _TrackingState.fromJson(Map<String, dynamic> json) => _$TrackingStateFromJson(json);

@override final  String bookingId;
@override final  BookingStatus status;
/// Present once a driver is allocated; null beforehand.
@override final  DriverInfo? driver;
/// Minutes until the driver reaches the pickup, when known.
@override final  int? etaMinutes;

/// Create a copy of TrackingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackingStateCopyWith<_TrackingState> get copyWith => __$TrackingStateCopyWithImpl<_TrackingState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrackingStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackingState&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.status, status) || other.status == status)&&(identical(other.driver, driver) || other.driver == driver)&&(identical(other.etaMinutes, etaMinutes) || other.etaMinutes == etaMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bookingId,status,driver,etaMinutes);

@override
String toString() {
  return 'TrackingState(bookingId: $bookingId, status: $status, driver: $driver, etaMinutes: $etaMinutes)';
}


}

/// @nodoc
abstract mixin class _$TrackingStateCopyWith<$Res> implements $TrackingStateCopyWith<$Res> {
  factory _$TrackingStateCopyWith(_TrackingState value, $Res Function(_TrackingState) _then) = __$TrackingStateCopyWithImpl;
@override @useResult
$Res call({
 String bookingId, BookingStatus status, DriverInfo? driver, int? etaMinutes
});


@override $DriverInfoCopyWith<$Res>? get driver;

}
/// @nodoc
class __$TrackingStateCopyWithImpl<$Res>
    implements _$TrackingStateCopyWith<$Res> {
  __$TrackingStateCopyWithImpl(this._self, this._then);

  final _TrackingState _self;
  final $Res Function(_TrackingState) _then;

/// Create a copy of TrackingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookingId = null,Object? status = null,Object? driver = freezed,Object? etaMinutes = freezed,}) {
  return _then(_TrackingState(
bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BookingStatus,driver: freezed == driver ? _self.driver : driver // ignore: cast_nullable_to_non_nullable
as DriverInfo?,etaMinutes: freezed == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of TrackingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DriverInfoCopyWith<$Res>? get driver {
    if (_self.driver == null) {
    return null;
  }

  return $DriverInfoCopyWith<$Res>(_self.driver!, (value) {
    return _then(_self.copyWith(driver: value));
  });
}
}


/// @nodoc
mixin _$DriverInfo {

 String get name; String get vehicle; String get plate; double get lat; double get lng;/// ARGB colour value the operator assigned this driver (matches the
/// driver-colour dots used across the platform). Rendered via
/// `Color(colorValue)` in presentation.
 int get colorValue;
/// Create a copy of DriverInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DriverInfoCopyWith<DriverInfo> get copyWith => _$DriverInfoCopyWithImpl<DriverInfo>(this as DriverInfo, _$identity);

  /// Serializes this DriverInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DriverInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.vehicle, vehicle) || other.vehicle == vehicle)&&(identical(other.plate, plate) || other.plate == plate)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.colorValue, colorValue) || other.colorValue == colorValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,vehicle,plate,lat,lng,colorValue);

@override
String toString() {
  return 'DriverInfo(name: $name, vehicle: $vehicle, plate: $plate, lat: $lat, lng: $lng, colorValue: $colorValue)';
}


}

/// @nodoc
abstract mixin class $DriverInfoCopyWith<$Res>  {
  factory $DriverInfoCopyWith(DriverInfo value, $Res Function(DriverInfo) _then) = _$DriverInfoCopyWithImpl;
@useResult
$Res call({
 String name, String vehicle, String plate, double lat, double lng, int colorValue
});




}
/// @nodoc
class _$DriverInfoCopyWithImpl<$Res>
    implements $DriverInfoCopyWith<$Res> {
  _$DriverInfoCopyWithImpl(this._self, this._then);

  final DriverInfo _self;
  final $Res Function(DriverInfo) _then;

/// Create a copy of DriverInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? vehicle = null,Object? plate = null,Object? lat = null,Object? lng = null,Object? colorValue = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,vehicle: null == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as String,plate: null == plate ? _self.plate : plate // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,colorValue: null == colorValue ? _self.colorValue : colorValue // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _DriverInfo implements DriverInfo {
  const _DriverInfo({required this.name, required this.vehicle, required this.plate, required this.lat, required this.lng, required this.colorValue});
  factory _DriverInfo.fromJson(Map<String, dynamic> json) => _$DriverInfoFromJson(json);

@override final  String name;
@override final  String vehicle;
@override final  String plate;
@override final  double lat;
@override final  double lng;
/// ARGB colour value the operator assigned this driver (matches the
/// driver-colour dots used across the platform). Rendered via
/// `Color(colorValue)` in presentation.
@override final  int colorValue;

/// Create a copy of DriverInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DriverInfoCopyWith<_DriverInfo> get copyWith => __$DriverInfoCopyWithImpl<_DriverInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DriverInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DriverInfo&&(identical(other.name, name) || other.name == name)&&(identical(other.vehicle, vehicle) || other.vehicle == vehicle)&&(identical(other.plate, plate) || other.plate == plate)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.colorValue, colorValue) || other.colorValue == colorValue));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,vehicle,plate,lat,lng,colorValue);

@override
String toString() {
  return 'DriverInfo(name: $name, vehicle: $vehicle, plate: $plate, lat: $lat, lng: $lng, colorValue: $colorValue)';
}


}

/// @nodoc
abstract mixin class _$DriverInfoCopyWith<$Res> implements $DriverInfoCopyWith<$Res> {
  factory _$DriverInfoCopyWith(_DriverInfo value, $Res Function(_DriverInfo) _then) = __$DriverInfoCopyWithImpl;
@override @useResult
$Res call({
 String name, String vehicle, String plate, double lat, double lng, int colorValue
});




}
/// @nodoc
class __$DriverInfoCopyWithImpl<$Res>
    implements _$DriverInfoCopyWith<$Res> {
  __$DriverInfoCopyWithImpl(this._self, this._then);

  final _DriverInfo _self;
  final $Res Function(_DriverInfo) _then;

/// Create a copy of DriverInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? vehicle = null,Object? plate = null,Object? lat = null,Object? lng = null,Object? colorValue = null,}) {
  return _then(_DriverInfo(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,vehicle: null == vehicle ? _self.vehicle : vehicle // ignore: cast_nullable_to_non_nullable
as String,plate: null == plate ? _self.plate : plate // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,colorValue: null == colorValue ? _self.colorValue : colorValue // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
