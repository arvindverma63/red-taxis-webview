// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'quote.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Quote {

 double get priceCash; double get priceAccount; double get totalMileage; int get totalMinutes; String get mileageText; String get durationText;
/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QuoteCopyWith<Quote> get copyWith => _$QuoteCopyWithImpl<Quote>(this as Quote, _$identity);

  /// Serializes this Quote to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Quote&&(identical(other.priceCash, priceCash) || other.priceCash == priceCash)&&(identical(other.priceAccount, priceAccount) || other.priceAccount == priceAccount)&&(identical(other.totalMileage, totalMileage) || other.totalMileage == totalMileage)&&(identical(other.totalMinutes, totalMinutes) || other.totalMinutes == totalMinutes)&&(identical(other.mileageText, mileageText) || other.mileageText == mileageText)&&(identical(other.durationText, durationText) || other.durationText == durationText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,priceCash,priceAccount,totalMileage,totalMinutes,mileageText,durationText);

@override
String toString() {
  return 'Quote(priceCash: $priceCash, priceAccount: $priceAccount, totalMileage: $totalMileage, totalMinutes: $totalMinutes, mileageText: $mileageText, durationText: $durationText)';
}


}

/// @nodoc
abstract mixin class $QuoteCopyWith<$Res>  {
  factory $QuoteCopyWith(Quote value, $Res Function(Quote) _then) = _$QuoteCopyWithImpl;
@useResult
$Res call({
 double priceCash, double priceAccount, double totalMileage, int totalMinutes, String mileageText, String durationText
});




}
/// @nodoc
class _$QuoteCopyWithImpl<$Res>
    implements $QuoteCopyWith<$Res> {
  _$QuoteCopyWithImpl(this._self, this._then);

  final Quote _self;
  final $Res Function(Quote) _then;

/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? priceCash = null,Object? priceAccount = null,Object? totalMileage = null,Object? totalMinutes = null,Object? mileageText = null,Object? durationText = null,}) {
  return _then(_self.copyWith(
priceCash: null == priceCash ? _self.priceCash : priceCash // ignore: cast_nullable_to_non_nullable
as double,priceAccount: null == priceAccount ? _self.priceAccount : priceAccount // ignore: cast_nullable_to_non_nullable
as double,totalMileage: null == totalMileage ? _self.totalMileage : totalMileage // ignore: cast_nullable_to_non_nullable
as double,totalMinutes: null == totalMinutes ? _self.totalMinutes : totalMinutes // ignore: cast_nullable_to_non_nullable
as int,mileageText: null == mileageText ? _self.mileageText : mileageText // ignore: cast_nullable_to_non_nullable
as String,durationText: null == durationText ? _self.durationText : durationText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _Quote implements Quote {
  const _Quote({this.priceCash = 0, this.priceAccount = 0, this.totalMileage = 0, this.totalMinutes = 0, this.mileageText = '', this.durationText = ''});
  factory _Quote.fromJson(Map<String, dynamic> json) => _$QuoteFromJson(json);

@override@JsonKey() final  double priceCash;
@override@JsonKey() final  double priceAccount;
@override@JsonKey() final  double totalMileage;
@override@JsonKey() final  int totalMinutes;
@override@JsonKey() final  String mileageText;
@override@JsonKey() final  String durationText;

/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$QuoteCopyWith<_Quote> get copyWith => __$QuoteCopyWithImpl<_Quote>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$QuoteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Quote&&(identical(other.priceCash, priceCash) || other.priceCash == priceCash)&&(identical(other.priceAccount, priceAccount) || other.priceAccount == priceAccount)&&(identical(other.totalMileage, totalMileage) || other.totalMileage == totalMileage)&&(identical(other.totalMinutes, totalMinutes) || other.totalMinutes == totalMinutes)&&(identical(other.mileageText, mileageText) || other.mileageText == mileageText)&&(identical(other.durationText, durationText) || other.durationText == durationText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,priceCash,priceAccount,totalMileage,totalMinutes,mileageText,durationText);

@override
String toString() {
  return 'Quote(priceCash: $priceCash, priceAccount: $priceAccount, totalMileage: $totalMileage, totalMinutes: $totalMinutes, mileageText: $mileageText, durationText: $durationText)';
}


}

/// @nodoc
abstract mixin class _$QuoteCopyWith<$Res> implements $QuoteCopyWith<$Res> {
  factory _$QuoteCopyWith(_Quote value, $Res Function(_Quote) _then) = __$QuoteCopyWithImpl;
@override @useResult
$Res call({
 double priceCash, double priceAccount, double totalMileage, int totalMinutes, String mileageText, String durationText
});




}
/// @nodoc
class __$QuoteCopyWithImpl<$Res>
    implements _$QuoteCopyWith<$Res> {
  __$QuoteCopyWithImpl(this._self, this._then);

  final _Quote _self;
  final $Res Function(_Quote) _then;

/// Create a copy of Quote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? priceCash = null,Object? priceAccount = null,Object? totalMileage = null,Object? totalMinutes = null,Object? mileageText = null,Object? durationText = null,}) {
  return _then(_Quote(
priceCash: null == priceCash ? _self.priceCash : priceCash // ignore: cast_nullable_to_non_nullable
as double,priceAccount: null == priceAccount ? _self.priceAccount : priceAccount // ignore: cast_nullable_to_non_nullable
as double,totalMileage: null == totalMileage ? _self.totalMileage : totalMileage // ignore: cast_nullable_to_non_nullable
as double,totalMinutes: null == totalMinutes ? _self.totalMinutes : totalMinutes // ignore: cast_nullable_to_non_nullable
as int,mileageText: null == mileageText ? _self.mileageText : mileageText // ignore: cast_nullable_to_non_nullable
as String,durationText: null == durationText ? _self.durationText : durationText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
