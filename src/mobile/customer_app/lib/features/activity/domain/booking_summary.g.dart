// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BookingSummary _$BookingSummaryFromJson(Map<String, dynamic> json) =>
    _BookingSummary(
      id: json['id'] as String,
      pickup: Place.fromJson(json['pickup'] as Map<String, dynamic>),
      dropoff: Place.fromJson(json['dropoff'] as Map<String, dynamic>),
      scheduledFor: DateTime.parse(json['scheduledFor'] as String),
      status: json['status'] as String,
      price: (json['price'] as num).toDouble(),
      vehicleName: json['vehicleName'] as String,
      passengers: (json['passengers'] as num).toInt(),
      paymentMethod: json['paymentMethod'] as String,
    );

Map<String, dynamic> _$BookingSummaryToJson(_BookingSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'pickup': instance.pickup,
      'dropoff': instance.dropoff,
      'scheduledFor': instance.scheduledFor.toIso8601String(),
      'status': instance.status,
      'price': instance.price,
      'vehicleName': instance.vehicleName,
      'passengers': instance.passengers,
      'paymentMethod': instance.paymentMethod,
    };
