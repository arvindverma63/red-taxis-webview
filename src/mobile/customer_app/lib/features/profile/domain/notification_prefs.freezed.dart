// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_prefs.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationPrefs {

 bool get cashBooking; bool get webBooking; bool get cancellations; bool get jobTimeouts;
/// Create a copy of NotificationPrefs
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPrefsCopyWith<NotificationPrefs> get copyWith => _$NotificationPrefsCopyWithImpl<NotificationPrefs>(this as NotificationPrefs, _$identity);

  /// Serializes this NotificationPrefs to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPrefs&&(identical(other.cashBooking, cashBooking) || other.cashBooking == cashBooking)&&(identical(other.webBooking, webBooking) || other.webBooking == webBooking)&&(identical(other.cancellations, cancellations) || other.cancellations == cancellations)&&(identical(other.jobTimeouts, jobTimeouts) || other.jobTimeouts == jobTimeouts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cashBooking,webBooking,cancellations,jobTimeouts);

@override
String toString() {
  return 'NotificationPrefs(cashBooking: $cashBooking, webBooking: $webBooking, cancellations: $cancellations, jobTimeouts: $jobTimeouts)';
}


}

/// @nodoc
abstract mixin class $NotificationPrefsCopyWith<$Res>  {
  factory $NotificationPrefsCopyWith(NotificationPrefs value, $Res Function(NotificationPrefs) _then) = _$NotificationPrefsCopyWithImpl;
@useResult
$Res call({
 bool cashBooking, bool webBooking, bool cancellations, bool jobTimeouts
});




}
/// @nodoc
class _$NotificationPrefsCopyWithImpl<$Res>
    implements $NotificationPrefsCopyWith<$Res> {
  _$NotificationPrefsCopyWithImpl(this._self, this._then);

  final NotificationPrefs _self;
  final $Res Function(NotificationPrefs) _then;

/// Create a copy of NotificationPrefs
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cashBooking = null,Object? webBooking = null,Object? cancellations = null,Object? jobTimeouts = null,}) {
  return _then(_self.copyWith(
cashBooking: null == cashBooking ? _self.cashBooking : cashBooking // ignore: cast_nullable_to_non_nullable
as bool,webBooking: null == webBooking ? _self.webBooking : webBooking // ignore: cast_nullable_to_non_nullable
as bool,cancellations: null == cancellations ? _self.cancellations : cancellations // ignore: cast_nullable_to_non_nullable
as bool,jobTimeouts: null == jobTimeouts ? _self.jobTimeouts : jobTimeouts // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _NotificationPrefs implements NotificationPrefs {
  const _NotificationPrefs({this.cashBooking = true, this.webBooking = true, this.cancellations = true, this.jobTimeouts = true});
  factory _NotificationPrefs.fromJson(Map<String, dynamic> json) => _$NotificationPrefsFromJson(json);

@override@JsonKey() final  bool cashBooking;
@override@JsonKey() final  bool webBooking;
@override@JsonKey() final  bool cancellations;
@override@JsonKey() final  bool jobTimeouts;

/// Create a copy of NotificationPrefs
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationPrefsCopyWith<_NotificationPrefs> get copyWith => __$NotificationPrefsCopyWithImpl<_NotificationPrefs>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationPrefsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationPrefs&&(identical(other.cashBooking, cashBooking) || other.cashBooking == cashBooking)&&(identical(other.webBooking, webBooking) || other.webBooking == webBooking)&&(identical(other.cancellations, cancellations) || other.cancellations == cancellations)&&(identical(other.jobTimeouts, jobTimeouts) || other.jobTimeouts == jobTimeouts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cashBooking,webBooking,cancellations,jobTimeouts);

@override
String toString() {
  return 'NotificationPrefs(cashBooking: $cashBooking, webBooking: $webBooking, cancellations: $cancellations, jobTimeouts: $jobTimeouts)';
}


}

/// @nodoc
abstract mixin class _$NotificationPrefsCopyWith<$Res> implements $NotificationPrefsCopyWith<$Res> {
  factory _$NotificationPrefsCopyWith(_NotificationPrefs value, $Res Function(_NotificationPrefs) _then) = __$NotificationPrefsCopyWithImpl;
@override @useResult
$Res call({
 bool cashBooking, bool webBooking, bool cancellations, bool jobTimeouts
});




}
/// @nodoc
class __$NotificationPrefsCopyWithImpl<$Res>
    implements _$NotificationPrefsCopyWith<$Res> {
  __$NotificationPrefsCopyWithImpl(this._self, this._then);

  final _NotificationPrefs _self;
  final $Res Function(_NotificationPrefs) _then;

/// Create a copy of NotificationPrefs
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cashBooking = null,Object? webBooking = null,Object? cancellations = null,Object? jobTimeouts = null,}) {
  return _then(_NotificationPrefs(
cashBooking: null == cashBooking ? _self.cashBooking : cashBooking // ignore: cast_nullable_to_non_nullable
as bool,webBooking: null == webBooking ? _self.webBooking : webBooking // ignore: cast_nullable_to_non_nullable
as bool,cancellations: null == cancellations ? _self.cancellations : cancellations // ignore: cast_nullable_to_non_nullable
as bool,jobTimeouts: null == jobTimeouts ? _self.jobTimeouts : jobTimeouts // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
