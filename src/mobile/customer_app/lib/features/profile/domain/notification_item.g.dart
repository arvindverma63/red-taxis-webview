// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationItem _$NotificationItemFromJson(Map<String, dynamic> json) =>
    _NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      time: DateTime.parse(json['time'] as String),
      type: json['type'] as String,
      bookingId: json['bookingId'] as String?,
      read: json['read'] as bool? ?? false,
    );

Map<String, dynamic> _$NotificationItemToJson(_NotificationItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': instance.body,
      'time': instance.time.toIso8601String(),
      'type': instance.type,
      'bookingId': instance.bookingId,
      'read': instance.read,
    };
