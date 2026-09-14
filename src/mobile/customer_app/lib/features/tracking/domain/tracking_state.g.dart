// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TrackingState _$TrackingStateFromJson(Map<String, dynamic> json) =>
    _TrackingState(
      bookingId: json['bookingId'] as String,
      status: $enumDecode(_$BookingStatusEnumMap, json['status']),
      driver: json['driver'] == null
          ? null
          : DriverInfo.fromJson(json['driver'] as Map<String, dynamic>),
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
    );

Map<String, dynamic> _$TrackingStateToJson(_TrackingState instance) =>
    <String, dynamic>{
      'bookingId': instance.bookingId,
      'status': _$BookingStatusEnumMap[instance.status]!,
      'driver': instance.driver,
      'etaMinutes': instance.etaMinutes,
    };

const _$BookingStatusEnumMap = {
  BookingStatus.requested: 'requested',
  BookingStatus.confirmed: 'confirmed',
  BookingStatus.allocated: 'allocated',
  BookingStatus.arriving: 'arriving',
  BookingStatus.arrived: 'arrived',
  BookingStatus.inProgress: 'inProgress',
  BookingStatus.completed: 'completed',
  BookingStatus.cancelled: 'cancelled',
};

_DriverInfo _$DriverInfoFromJson(Map<String, dynamic> json) => _DriverInfo(
  name: json['name'] as String,
  vehicle: json['vehicle'] as String,
  plate: json['plate'] as String,
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
  colorValue: (json['colorValue'] as num).toInt(),
);

Map<String, dynamic> _$DriverInfoToJson(_DriverInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'vehicle': instance.vehicle,
      'plate': instance.plate,
      'lat': instance.lat,
      'lng': instance.lng,
      'colorValue': instance.colorValue,
    };
