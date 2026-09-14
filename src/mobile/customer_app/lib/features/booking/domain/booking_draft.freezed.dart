// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'booking_draft.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookingDraft {

 Place? get pickup; Place? get dropoff; List<Place> get vias; String get vehicleId; int get passengers; DateTime? get scheduledFor; String get paymentMethod; Quote? get quote;
/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingDraftCopyWith<BookingDraft> get copyWith => _$BookingDraftCopyWithImpl<BookingDraft>(this as BookingDraft, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingDraft&&(identical(other.pickup, pickup) || other.pickup == pickup)&&(identical(other.dropoff, dropoff) || other.dropoff == dropoff)&&const DeepCollectionEquality().equals(other.vias, vias)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.passengers, passengers) || other.passengers == passengers)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.quote, quote) || other.quote == quote));
}


@override
int get hashCode => Object.hash(runtimeType,pickup,dropoff,const DeepCollectionEquality().hash(vias),vehicleId,passengers,scheduledFor,paymentMethod,quote);

@override
String toString() {
  return 'BookingDraft(pickup: $pickup, dropoff: $dropoff, vias: $vias, vehicleId: $vehicleId, passengers: $passengers, scheduledFor: $scheduledFor, paymentMethod: $paymentMethod, quote: $quote)';
}


}

/// @nodoc
abstract mixin class $BookingDraftCopyWith<$Res>  {
  factory $BookingDraftCopyWith(BookingDraft value, $Res Function(BookingDraft) _then) = _$BookingDraftCopyWithImpl;
@useResult
$Res call({
 Place? pickup, Place? dropoff, List<Place> vias, String vehicleId, int passengers, DateTime? scheduledFor, String paymentMethod, Quote? quote
});


$PlaceCopyWith<$Res>? get pickup;$PlaceCopyWith<$Res>? get dropoff;$QuoteCopyWith<$Res>? get quote;

}
/// @nodoc
class _$BookingDraftCopyWithImpl<$Res>
    implements $BookingDraftCopyWith<$Res> {
  _$BookingDraftCopyWithImpl(this._self, this._then);

  final BookingDraft _self;
  final $Res Function(BookingDraft) _then;

/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pickup = freezed,Object? dropoff = freezed,Object? vias = null,Object? vehicleId = null,Object? passengers = null,Object? scheduledFor = freezed,Object? paymentMethod = null,Object? quote = freezed,}) {
  return _then(_self.copyWith(
pickup: freezed == pickup ? _self.pickup : pickup // ignore: cast_nullable_to_non_nullable
as Place?,dropoff: freezed == dropoff ? _self.dropoff : dropoff // ignore: cast_nullable_to_non_nullable
as Place?,vias: null == vias ? _self.vias : vias // ignore: cast_nullable_to_non_nullable
as List<Place>,vehicleId: null == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as String,passengers: null == passengers ? _self.passengers : passengers // ignore: cast_nullable_to_non_nullable
as int,scheduledFor: freezed == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as DateTime?,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,quote: freezed == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as Quote?,
  ));
}
/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceCopyWith<$Res>? get pickup {
    if (_self.pickup == null) {
    return null;
  }

  return $PlaceCopyWith<$Res>(_self.pickup!, (value) {
    return _then(_self.copyWith(pickup: value));
  });
}/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceCopyWith<$Res>? get dropoff {
    if (_self.dropoff == null) {
    return null;
  }

  return $PlaceCopyWith<$Res>(_self.dropoff!, (value) {
    return _then(_self.copyWith(dropoff: value));
  });
}/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuoteCopyWith<$Res>? get quote {
    if (_self.quote == null) {
    return null;
  }

  return $QuoteCopyWith<$Res>(_self.quote!, (value) {
    return _then(_self.copyWith(quote: value));
  });
}
}


/// @nodoc


class _BookingDraft extends BookingDraft {
  const _BookingDraft({this.pickup, this.dropoff, final  List<Place> vias = const <Place>[], this.vehicleId = 'saloon', this.passengers = 1, this.scheduledFor, this.paymentMethod = 'cash', this.quote}): _vias = vias,super._();
  

@override final  Place? pickup;
@override final  Place? dropoff;
 final  List<Place> _vias;
@override@JsonKey() List<Place> get vias {
  if (_vias is EqualUnmodifiableListView) return _vias;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_vias);
}

@override@JsonKey() final  String vehicleId;
@override@JsonKey() final  int passengers;
@override final  DateTime? scheduledFor;
@override@JsonKey() final  String paymentMethod;
@override final  Quote? quote;

/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingDraftCopyWith<_BookingDraft> get copyWith => __$BookingDraftCopyWithImpl<_BookingDraft>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingDraft&&(identical(other.pickup, pickup) || other.pickup == pickup)&&(identical(other.dropoff, dropoff) || other.dropoff == dropoff)&&const DeepCollectionEquality().equals(other._vias, _vias)&&(identical(other.vehicleId, vehicleId) || other.vehicleId == vehicleId)&&(identical(other.passengers, passengers) || other.passengers == passengers)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.quote, quote) || other.quote == quote));
}


@override
int get hashCode => Object.hash(runtimeType,pickup,dropoff,const DeepCollectionEquality().hash(_vias),vehicleId,passengers,scheduledFor,paymentMethod,quote);

@override
String toString() {
  return 'BookingDraft(pickup: $pickup, dropoff: $dropoff, vias: $vias, vehicleId: $vehicleId, passengers: $passengers, scheduledFor: $scheduledFor, paymentMethod: $paymentMethod, quote: $quote)';
}


}

/// @nodoc
abstract mixin class _$BookingDraftCopyWith<$Res> implements $BookingDraftCopyWith<$Res> {
  factory _$BookingDraftCopyWith(_BookingDraft value, $Res Function(_BookingDraft) _then) = __$BookingDraftCopyWithImpl;
@override @useResult
$Res call({
 Place? pickup, Place? dropoff, List<Place> vias, String vehicleId, int passengers, DateTime? scheduledFor, String paymentMethod, Quote? quote
});


@override $PlaceCopyWith<$Res>? get pickup;@override $PlaceCopyWith<$Res>? get dropoff;@override $QuoteCopyWith<$Res>? get quote;

}
/// @nodoc
class __$BookingDraftCopyWithImpl<$Res>
    implements _$BookingDraftCopyWith<$Res> {
  __$BookingDraftCopyWithImpl(this._self, this._then);

  final _BookingDraft _self;
  final $Res Function(_BookingDraft) _then;

/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pickup = freezed,Object? dropoff = freezed,Object? vias = null,Object? vehicleId = null,Object? passengers = null,Object? scheduledFor = freezed,Object? paymentMethod = null,Object? quote = freezed,}) {
  return _then(_BookingDraft(
pickup: freezed == pickup ? _self.pickup : pickup // ignore: cast_nullable_to_non_nullable
as Place?,dropoff: freezed == dropoff ? _self.dropoff : dropoff // ignore: cast_nullable_to_non_nullable
as Place?,vias: null == vias ? _self._vias : vias // ignore: cast_nullable_to_non_nullable
as List<Place>,vehicleId: null == vehicleId ? _self.vehicleId : vehicleId // ignore: cast_nullable_to_non_nullable
as String,passengers: null == passengers ? _self.passengers : passengers // ignore: cast_nullable_to_non_nullable
as int,scheduledFor: freezed == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as DateTime?,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,quote: freezed == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as Quote?,
  ));
}

/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceCopyWith<$Res>? get pickup {
    if (_self.pickup == null) {
    return null;
  }

  return $PlaceCopyWith<$Res>(_self.pickup!, (value) {
    return _then(_self.copyWith(pickup: value));
  });
}/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlaceCopyWith<$Res>? get dropoff {
    if (_self.dropoff == null) {
    return null;
  }

  return $PlaceCopyWith<$Res>(_self.dropoff!, (value) {
    return _then(_self.copyWith(dropoff: value));
  });
}/// Create a copy of BookingDraft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuoteCopyWith<$Res>? get quote {
    if (_self.quote == null) {
    return null;
  }

  return $QuoteCopyWith<$Res>(_self.quote!, (value) {
    return _then(_self.copyWith(quote: value));
  });
}
}

// dart format on
