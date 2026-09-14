// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentIntent _$PaymentIntentFromJson(Map<String, dynamic> json) =>
    _PaymentIntent(
      orderId: json['orderId'] as String,
      checkoutUrl: json['checkoutUrl'] as String?,
      status: json['status'] as String,
    );

Map<String, dynamic> _$PaymentIntentToJson(_PaymentIntent instance) =>
    <String, dynamic>{
      'orderId': instance.orderId,
      'checkoutUrl': instance.checkoutUrl,
      'status': instance.status,
    };
