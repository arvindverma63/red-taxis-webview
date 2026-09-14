// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_suggestion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AddressSuggestion _$AddressSuggestionFromJson(Map<String, dynamic> json) =>
    _AddressSuggestion(
      placeId: json['placeId'] as String,
      description: json['description'] as String? ?? '',
      mainText: json['mainText'] as String? ?? '',
      secondaryText: json['secondaryText'] as String? ?? '',
      postcode: json['postcode'] as String?,
    );

Map<String, dynamic> _$AddressSuggestionToJson(_AddressSuggestion instance) =>
    <String, dynamic>{
      'placeId': instance.placeId,
      'description': instance.description,
      'mainText': instance.mainText,
      'secondaryText': instance.secondaryText,
      'postcode': instance.postcode,
    };
