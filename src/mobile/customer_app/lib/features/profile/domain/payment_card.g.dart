// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentCard _$PaymentCardFromJson(Map<String, dynamic> json) => _PaymentCard(
  id: json['id'] as String,
  brand: json['brand'] as String,
  last4: json['last4'] as String? ?? '',
  label: json['label'] as String,
  isDefault: json['isDefault'] as bool? ?? false,
);

Map<String, dynamic> _$PaymentCardToJson(_PaymentCard instance) =>
    <String, dynamic>{
      'id': instance.id,
      'brand': instance.brand,
      'last4': instance.last4,
      'label': instance.label,
      'isDefault': instance.isDefault,
    };
