// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'booking_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookingSummary {

 String get id; Place get pickup; Place get dropoff; DateTime get scheduledFor; String get status; double get price; String get vehicleName; int get passengers; String get paymentMethod;
/// Create a copy of BookingSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingSummaryCopyWith<BookingSummary> get copyWith => _$BookingSummaryCopyWithImpl<BookingSummary>(this as BookingSummary, _$identity);

  /// Serializes this BookingSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.pickup, pickup) || other.pickup == pickup)&&(identical(other.dropoff, dropoff) || other.dropoff == dropoff)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.status, status) || other.status == status)&&(identical(other.price, price) || other.price == price)&&(identical(other.vehicleName, vehicleName) || other.vehicleName == vehicleName)&&(identical(other.passengers, passengers) || other.passengers == passengers)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,pickup,dropoff,scheduledFor,status,price,vehicleName,passengers,paymentMethod);

@override
String toString() {
  return 'BookingSummary(id: $id, pickup: $pickup, dropoff: $dropoff, scheduledFor: $scheduledFor, status: $status, price: $price, vehicleName: $vehicleName, passengers: $passengers, paymentMethod: $paymentMethod)';
}


}

/// @nodoc
abstract mixin class $BookingSummaryCopyWith<$Res>  {
  factory $BookingSummaryCopyWith(BookingSummary value, $Res Function(BookingSummary) _then) = _$BookingSummaryCopyWithImpl;
@useResult
$Res call({
 String id, Place pickup, Place dropoff, DateTime scheduledFor, String status, double price, String vehicleName, int passengers, String paymentMethod
});


$PlaceCopyWith<$Res> get pickup;$PlaceCopyWith<$Res> get dropoff;

}
/// @nodoc
class _$BookingSummaryCopyWithImpl<$Res>
    implements $BookingSummaryCopyWith<$Res> {
  _$BookingSummaryCopyWithImpl(this._self, this._then);

  final BookingSummary _self;
  final $Res Function(BookingSummary) _then;

/// Create a copy of BookingSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? pickup = null,Object? dropoff = null,Object? scheduledFor = null,Object? status = null,Object? price = null,Object? vehicleName = null,Object? passengers = null,Object? paymentMethod = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,pickup: null == pickup ? _self.pickup : pickup // ignore: cast_nullable_to_non_nullable
as Place,dropoff: null == dropoff ? _self.dropoff : dropoff // ignore: cast_nullable_to_non_nullable
as Place,scheduledFor: null == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,vehicleName: null == vehicleName ? _self.vehicleName : vehicleName // ignore: cast_nullable_to_non_nullable
as String,passengers: null == passengers ? _self.passengers : passengers // ignore: cast_nullable_to_non_nullable
as int,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of BookingSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceCopyWith<$Res> get pickup {
  
  return $PlaceCopyWith<$Res>(_self.pickup, (value) {
    return _then(_self.copyWith(pickup: value));
  });
}/// Create a copy of BookingSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceCopyWith<$Res> get dropoff {
  
  return $PlaceCopyWith<$Res>(_self.dropoff, (value) {
    return _then(_self.copyWith(dropoff: value));
  });
}
}


/// @nodoc
@JsonSerializable()

class _BookingSummary extends BookingSummary {
  const _BookingSummary({required this.id, required this.pickup, required this.dropoff, required this.scheduledFor, required this.status, required this.price, required this.vehicleName, required this.passengers, required this.paymentMethod}): super._();
  factory _BookingSummary.fromJson(Map<String, dynamic> json) => _$BookingSummaryFromJson(json);

@override final  String id;
@override final  Place pickup;
@override final  Place dropoff;
@override final  DateTime scheduledFor;
@override final  String status;
@override final  double price;
@override final  String vehicleName;
@override final  int passengers;
@override final  String paymentMethod;

/// Create a copy of BookingSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingSummaryCopyWith<_BookingSummary> get copyWith => __$BookingSummaryCopyWithImpl<_BookingSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.pickup, pickup) || other.pickup == pickup)&&(identical(other.dropoff, dropoff) || other.dropoff == dropoff)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.status, status) || other.status == status)&&(identical(other.price, price) || other.price == price)&&(identical(other.vehicleName, vehicleName) || other.vehicleName == vehicleName)&&(identical(other.passengers, passengers) || other.passengers == passengers)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,pickup,dropoff,scheduledFor,status,price,vehicleName,passengers,paymentMethod);

@override
String toString() {
  return 'BookingSummary(id: $id, pickup: $pickup, dropoff: $dropoff, scheduledFor: $scheduledFor, status: $status, price: $price, vehicleName: $vehicleName, passengers: $passengers, paymentMethod: $paymentMethod)';
}


}

/// @nodoc
abstract mixin class _$BookingSummaryCopyWith<$Res> implements $BookingSummaryCopyWith<$Res> {
  factory _$BookingSummaryCopyWith(_BookingSummary value, $Res Function(_BookingSummary) _then) = __$BookingSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, Place pickup, Place dropoff, DateTime scheduledFor, String status, double price, String vehicleName, int passengers, String paymentMethod
});


@override $PlaceCopyWith<$Res> get pickup;@override $PlaceCopyWith<$Res> get dropoff;

}
/// @nodoc
class __$BookingSummaryCopyWithImpl<$Res>
    implements _$BookingSummaryCopyWith<$Res> {
  __$BookingSummaryCopyWithImpl(this._self, this._then);

  final _BookingSummary _self;
  final $Res Function(_BookingSummary) _then;

/// Create a copy of BookingSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? pickup = null,Object? dropoff = null,Object? scheduledFor = null,Object? status = null,Object? price = null,Object? vehicleName = null,Object? passengers = null,Object? paymentMethod = null,}) {
  return _then(_BookingSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,pickup: null == pickup ? _self.pickup : pickup // ignore: cast_nullable_to_non_nullable
as Place,dropoff: null == dropoff ? _self.dropoff : dropoff // ignore: cast_nullable_to_non_nullable
as Place,scheduledFor: null == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,vehicleName: null == vehicleName ? _self.vehicleName : vehicleName // ignore: cast_nullable_to_non_nullable
as String,passengers: null == passengers ? _self.passengers : passengers // ignore: cast_nullable_to_non_nullable
as int,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of BookingSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceCopyWith<$Res> get pickup {
  
  return $PlaceCopyWith<$Res>(_self.pickup, (value) {
    return _then(_self.copyWith(pickup: value));
  });
}/// Create a copy of BookingSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceCopyWith<$Res> get dropoff {
  
  return $PlaceCopyWith<$Res>(_self.dropoff, (value) {
    return _then(_self.copyWith(dropoff: value));
  });
}
}

// dart format on
