// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quote.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Quote _$QuoteFromJson(Map<String, dynamic> json) => _Quote(
  priceCash: (json['priceCash'] as num?)?.toDouble() ?? 0,
  priceAccount: (json['priceAccount'] as num?)?.toDouble() ?? 0,
  totalMileage: (json['totalMileage'] as num?)?.toDouble() ?? 0,
  totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,
  mileageText: json['mileageText'] as String? ?? '',
  durationText: json['durationText'] as String? ?? '',
);

Map<String, dynamic> _$QuoteToJson(_Quote instance) => <String, dynamic>{
  'priceCash': instance.priceCash,
  'priceAccount': instance.priceAccount,
  'totalMileage': instance.totalMileage,
  'totalMinutes': instance.totalMinutes,
  'mileageText': instance.mileageText,
  'durationText': instance.durationText,
};
