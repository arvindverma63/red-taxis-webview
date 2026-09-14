// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'address_suggestion.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AddressSuggestion {

 String get placeId; String get description; String get mainText; String get secondaryText; String? get postcode;
/// Create a copy of AddressSuggestion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AddressSuggestionCopyWith<AddressSuggestion> get copyWith => _$AddressSuggestionCopyWithImpl<AddressSuggestion>(this as AddressSuggestion, _$identity);

  /// Serializes this AddressSuggestion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AddressSuggestion&&(identical(other.placeId, placeId) || other.placeId == placeId)&&(identical(other.description, description) || other.description == description)&&(identical(other.mainText, mainText) || other.mainText == mainText)&&(identical(other.secondaryText, secondaryText) || other.secondaryText == secondaryText)&&(identical(other.postcode, postcode) || other.postcode == postcode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,placeId,description,mainText,secondaryText,postcode);

@override
String toString() {
  return 'AddressSuggestion(placeId: $placeId, description: $description, mainText: $mainText, secondaryText: $secondaryText, postcode: $postcode)';
}


}

/// @nodoc
abstract mixin class $AddressSuggestionCopyWith<$Res>  {
  factory $AddressSuggestionCopyWith(AddressSuggestion value, $Res Function(AddressSuggestion) _then) = _$AddressSuggestionCopyWithImpl;
@useResult
$Res call({
 String placeId, String description, String mainText, String secondaryText, String? postcode
});




}
/// @nodoc
class _$AddressSuggestionCopyWithImpl<$Res>
    implements $AddressSuggestionCopyWith<$Res> {
  _$AddressSuggestionCopyWithImpl(this._self, this._then);

  final AddressSuggestion _self;
  final $Res Function(AddressSuggestion) _then;

/// Create a copy of AddressSuggestion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? placeId = null,Object? description = null,Object? mainText = null,Object? secondaryText = null,Object? postcode = freezed,}) {
  return _then(_self.copyWith(
placeId: null == placeId ? _self.placeId : placeId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,mainText: null == mainText ? _self.mainText : mainText // ignore: cast_nullable_to_non_nullable
as String,secondaryText: null == secondaryText ? _self.secondaryText : secondaryText // ignore: cast_nullable_to_non_nullable
as String,postcode: freezed == postcode ? _self.postcode : postcode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _AddressSuggestion implements AddressSuggestion {
  const _AddressSuggestion({required this.placeId, this.description = '', this.mainText = '', this.secondaryText = '', this.postcode});
  factory _AddressSuggestion.fromJson(Map<String, dynamic> json) => _$AddressSuggestionFromJson(json);

@override final  String placeId;
@override@JsonKey() final  String description;
@override@JsonKey() final  String mainText;
@override@JsonKey() final  String secondaryText;
@override final  String? postcode;

/// Create a copy of AddressSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AddressSuggestionCopyWith<_AddressSuggestion> get copyWith => __$AddressSuggestionCopyWithImpl<_AddressSuggestion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AddressSuggestionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AddressSuggestion&&(identical(other.placeId, placeId) || other.placeId == placeId)&&(identical(other.description, description) || other.description == description)&&(identical(other.mainText, mainText) || other.mainText == mainText)&&(identical(other.secondaryText, secondaryText) || other.secondaryText == secondaryText)&&(identical(other.postcode, postcode) || other.postcode == postcode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,placeId,description,mainText,secondaryText,postcode);

@override
String toString() {
  return 'AddressSuggestion(placeId: $placeId, description: $description, mainText: $mainText, secondaryText: $secondaryText, postcode: $postcode)';
}


}

/// @nodoc
abstract mixin class _$AddressSuggestionCopyWith<$Res> implements $AddressSuggestionCopyWith<$Res> {
  factory _$AddressSuggestionCopyWith(_AddressSuggestion value, $Res Function(_AddressSuggestion) _then) = __$AddressSuggestionCopyWithImpl;
@override @useResult
$Res call({
 String placeId, String description, String mainText, String secondaryText, String? postcode
});




}
/// @nodoc
class __$AddressSuggestionCopyWithImpl<$Res>
    implements _$AddressSuggestionCopyWith<$Res> {
  __$AddressSuggestionCopyWithImpl(this._self, this._then);

  final _AddressSuggestion _self;
  final $Res Function(_AddressSuggestion) _then;

/// Create a copy of AddressSuggestion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? placeId = null,Object? description = null,Object? mainText = null,Object? secondaryText = null,Object? postcode = freezed,}) {
  return _then(_AddressSuggestion(
placeId: null == placeId ? _self.placeId : placeId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,mainText: null == mainText ? _self.mainText : mainText // ignore: cast_nullable_to_non_nullable
as String,secondaryText: null == secondaryText ? _self.secondaryText : secondaryText // ignore: cast_nullable_to_non_nullable
as String,postcode: freezed == postcode ? _self.postcode : postcode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
