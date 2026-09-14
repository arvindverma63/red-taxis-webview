// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_card.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentCard {

 String get id;/// Card brand or wallet: `visa`, `mastercard`, `applePay`.
 String get brand;/// Last four digits (empty for wallet methods such as Apple Pay).
 String get last4;/// Human label shown in the list (e.g. "Personal Visa").
 String get label;/// Whether this is the default method pre-selected at checkout.
 bool get isDefault;
/// Create a copy of PaymentCard
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentCardCopyWith<PaymentCard> get copyWith => _$PaymentCardCopyWithImpl<PaymentCard>(this as PaymentCard, _$identity);

  /// Serializes this PaymentCard to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentCard&&(identical(other.id, id) || other.id == id)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.last4, last4) || other.last4 == last4)&&(identical(other.label, label) || other.label == label)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,brand,last4,label,isDefault);

@override
String toString() {
  return 'PaymentCard(id: $id, brand: $brand, last4: $last4, label: $label, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class $PaymentCardCopyWith<$Res>  {
  factory $PaymentCardCopyWith(PaymentCard value, $Res Function(PaymentCard) _then) = _$PaymentCardCopyWithImpl;
@useResult
$Res call({
 String id, String brand, String last4, String label, bool isDefault
});




}
/// @nodoc
class _$PaymentCardCopyWithImpl<$Res>
    implements $PaymentCardCopyWith<$Res> {
  _$PaymentCardCopyWithImpl(this._self, this._then);

  final PaymentCard _self;
  final $Res Function(PaymentCard) _then;

/// Create a copy of PaymentCard
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? brand = null,Object? last4 = null,Object? label = null,Object? isDefault = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,brand: null == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String,last4: null == last4 ? _self.last4 : last4 // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _PaymentCard implements PaymentCard {
  const _PaymentCard({required this.id, required this.brand, this.last4 = '', required this.label, this.isDefault = false});
  factory _PaymentCard.fromJson(Map<String, dynamic> json) => _$PaymentCardFromJson(json);

@override final  String id;
/// Card brand or wallet: `visa`, `mastercard`, `applePay`.
@override final  String brand;
/// Last four digits (empty for wallet methods such as Apple Pay).
@override@JsonKey() final  String last4;
/// Human label shown in the list (e.g. "Personal Visa").
@override final  String label;
/// Whether this is the default method pre-selected at checkout.
@override@JsonKey() final  bool isDefault;

/// Create a copy of PaymentCard
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentCardCopyWith<_PaymentCard> get copyWith => __$PaymentCardCopyWithImpl<_PaymentCard>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentCardToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentCard&&(identical(other.id, id) || other.id == id)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.last4, last4) || other.last4 == last4)&&(identical(other.label, label) || other.label == label)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,brand,last4,label,isDefault);

@override
String toString() {
  return 'PaymentCard(id: $id, brand: $brand, last4: $last4, label: $label, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class _$PaymentCardCopyWith<$Res> implements $PaymentCardCopyWith<$Res> {
  factory _$PaymentCardCopyWith(_PaymentCard value, $Res Function(_PaymentCard) _then) = __$PaymentCardCopyWithImpl;
@override @useResult
$Res call({
 String id, String brand, String last4, String label, bool isDefault
});




}
/// @nodoc
class __$PaymentCardCopyWithImpl<$Res>
    implements _$PaymentCardCopyWith<$Res> {
  __$PaymentCardCopyWithImpl(this._self, this._then);

  final _PaymentCard _self;
  final $Res Function(_PaymentCard) _then;

/// Create a copy of PaymentCard
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? brand = null,Object? last4 = null,Object? label = null,Object? isDefault = null,}) {
  return _then(_PaymentCard(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,brand: null == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String,last4: null == last4 ? _self.last4 : last4 // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
