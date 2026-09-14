// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationItem {

 String get id; String get title; String get body;/// When the notification was raised.
 DateTime get time;/// Event type: `booking_confirmed`, `driver_arriving`, `driver_arrived`,
/// `booking_completed`, `booking_cancelled`, `payment_receipt`, `general`.
 String get type;/// Linked booking id, when the event relates to a specific journey.
 String? get bookingId;/// Whether the customer has opened/read this notification.
 bool get read;
/// Create a copy of NotificationItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationItemCopyWith<NotificationItem> get copyWith => _$NotificationItemCopyWithImpl<NotificationItem>(this as NotificationItem, _$identity);

  /// Serializes this NotificationItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationItem&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.time, time) || other.time == time)&&(identical(other.type, type) || other.type == type)&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.read, read) || other.read == read));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,body,time,type,bookingId,read);

@override
String toString() {
  return 'NotificationItem(id: $id, title: $title, body: $body, time: $time, type: $type, bookingId: $bookingId, read: $read)';
}


}

/// @nodoc
abstract mixin class $NotificationItemCopyWith<$Res>  {
  factory $NotificationItemCopyWith(NotificationItem value, $Res Function(NotificationItem) _then) = _$NotificationItemCopyWithImpl;
@useResult
$Res call({
 String id, String title, String body, DateTime time, String type, String? bookingId, bool read
});




}
/// @nodoc
class _$NotificationItemCopyWithImpl<$Res>
    implements $NotificationItemCopyWith<$Res> {
  _$NotificationItemCopyWithImpl(this._self, this._then);

  final NotificationItem _self;
  final $Res Function(NotificationItem) _then;

/// Create a copy of NotificationItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? body = null,Object? time = null,Object? type = null,Object? bookingId = freezed,Object? read = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as DateTime,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,bookingId: freezed == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String?,read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _NotificationItem implements NotificationItem {
  const _NotificationItem({required this.id, required this.title, required this.body, required this.time, required this.type, this.bookingId, this.read = false});
  factory _NotificationItem.fromJson(Map<String, dynamic> json) => _$NotificationItemFromJson(json);

@override final  String id;
@override final  String title;
@override final  String body;
/// When the notification was raised.
@override final  DateTime time;
/// Event type: `booking_confirmed`, `driver_arriving`, `driver_arrived`,
/// `booking_completed`, `booking_cancelled`, `payment_receipt`, `general`.
@override final  String type;
/// Linked booking id, when the event relates to a specific journey.
@override final  String? bookingId;
/// Whether the customer has opened/read this notification.
@override@JsonKey() final  bool read;

/// Create a copy of NotificationItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationItemCopyWith<_NotificationItem> get copyWith => __$NotificationItemCopyWithImpl<_NotificationItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationItem&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body)&&(identical(other.time, time) || other.time == time)&&(identical(other.type, type) || other.type == type)&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.read, read) || other.read == read));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,body,time,type,bookingId,read);

@override
String toString() {
  return 'NotificationItem(id: $id, title: $title, body: $body, time: $time, type: $type, bookingId: $bookingId, read: $read)';
}


}

/// @nodoc
abstract mixin class _$NotificationItemCopyWith<$Res> implements $NotificationItemCopyWith<$Res> {
  factory _$NotificationItemCopyWith(_NotificationItem value, $Res Function(_NotificationItem) _then) = __$NotificationItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String body, DateTime time, String type, String? bookingId, bool read
});




}
/// @nodoc
class __$NotificationItemCopyWithImpl<$Res>
    implements _$NotificationItemCopyWith<$Res> {
  __$NotificationItemCopyWithImpl(this._self, this._then);

  final _NotificationItem _self;
  final $Res Function(_NotificationItem) _then;

/// Create a copy of NotificationItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? body = null,Object? time = null,Object? type = null,Object? bookingId = freezed,Object? read = null,}) {
  return _then(_NotificationItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as DateTime,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,bookingId: freezed == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String?,read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
