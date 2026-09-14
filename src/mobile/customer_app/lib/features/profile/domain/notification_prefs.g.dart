// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_prefs.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationPrefs _$NotificationPrefsFromJson(Map<String, dynamic> json) =>
    _NotificationPrefs(
      cashBooking: json['cashBooking'] as bool? ?? true,
      webBooking: json['webBooking'] as bool? ?? true,
      cancellations: json['cancellations'] as bool? ?? true,
      jobTimeouts: json['jobTimeouts'] as bool? ?? true,
    );

Map<String, dynamic> _$NotificationPrefsToJson(_NotificationPrefs instance) =>
    <String, dynamic>{
      'cashBooking': instance.cashBooking,
      'webBooking': instance.webBooking,
      'cancellations': instance.cancellations,
      'jobTimeouts': instance.jobTimeouts,
    };
