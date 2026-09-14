// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentIntent {

 String get orderId; String? get checkoutUrl; String get status;
/// Create a copy of PaymentIntent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentIntentCopyWith<PaymentIntent> get copyWith => _$PaymentIntentCopyWithImpl<PaymentIntent>(this as PaymentIntent, _$identity);

  /// Serializes this PaymentIntent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentIntent&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.checkoutUrl, checkoutUrl) || other.checkoutUrl == checkoutUrl)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderId,checkoutUrl,status);

@override
String toString() {
  return 'PaymentIntent(orderId: $orderId, checkoutUrl: $checkoutUrl, status: $status)';
}


}

/// @nodoc
abstract mixin class $PaymentIntentCopyWith<$Res>  {
  factory $PaymentIntentCopyWith(PaymentIntent value, $Res Function(PaymentIntent) _then) = _$PaymentIntentCopyWithImpl;
@useResult
$Res call({
 String orderId, String? checkoutUrl, String status
});




}
/// @nodoc
class _$PaymentIntentCopyWithImpl<$Res>
    implements $PaymentIntentCopyWith<$Res> {
  _$PaymentIntentCopyWithImpl(this._self, this._then);

  final PaymentIntent _self;
  final $Res Function(PaymentIntent) _then;

/// Create a copy of PaymentIntent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? orderId = null,Object? checkoutUrl = freezed,Object? status = null,}) {
  return _then(_self.copyWith(
orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,checkoutUrl: freezed == checkoutUrl ? _self.checkoutUrl : checkoutUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _PaymentIntent extends PaymentIntent {
  const _PaymentIntent({required this.orderId, this.checkoutUrl, required this.status}): super._();
  factory _PaymentIntent.fromJson(Map<String, dynamic> json) => _$PaymentIntentFromJson(json);

@override final  String orderId;
@override final  String? checkoutUrl;
@override final  String status;

/// Create a copy of PaymentIntent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentIntentCopyWith<_PaymentIntent> get copyWith => __$PaymentIntentCopyWithImpl<_PaymentIntent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentIntentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentIntent&&(identical(other.orderId, orderId) || other.orderId == orderId)&&(identical(other.checkoutUrl, checkoutUrl) || other.checkoutUrl == checkoutUrl)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,orderId,checkoutUrl,status);

@override
String toString() {
  return 'PaymentIntent(orderId: $orderId, checkoutUrl: $checkoutUrl, status: $status)';
}


}

/// @nodoc
abstract mixin class _$PaymentIntentCopyWith<$Res> implements $PaymentIntentCopyWith<$Res> {
  factory _$PaymentIntentCopyWith(_PaymentIntent value, $Res Function(_PaymentIntent) _then) = __$PaymentIntentCopyWithImpl;
@override @useResult
$Res call({
 String orderId, String? checkoutUrl, String status
});




}
/// @nodoc
class __$PaymentIntentCopyWithImpl<$Res>
    implements _$PaymentIntentCopyWith<$Res> {
  __$PaymentIntentCopyWithImpl(this._self, this._then);

  final _PaymentIntent _self;
  final $Res Function(_PaymentIntent) _then;

/// Create a copy of PaymentIntent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? orderId = null,Object? checkoutUrl = freezed,Object? status = null,}) {
  return _then(_PaymentIntent(
orderId: null == orderId ? _self.orderId : orderId // ignore: cast_nullable_to_non_nullable
as String,checkoutUrl: freezed == checkoutUrl ? _self.checkoutUrl : checkoutUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
