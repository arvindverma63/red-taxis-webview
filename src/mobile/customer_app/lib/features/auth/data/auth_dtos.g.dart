// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthSession _$AuthSessionFromJson(Map<String, dynamic> json) => _AuthSession(
  userId: (json['userId'] as num).toInt(),
  username: json['username'] as String,
  fullName: json['fullName'] as String? ?? '',
  role: json['role'] as String? ?? '',
  roleId: (json['roleId'] as num?)?.toInt(),
  isAdmin: json['isAdmin'] as bool? ?? false,
  email: json['email'] as String?,
  phoneNumber: json['phoneNumber'] as String?,
  token: json['token'] as String,
  tokenExpiry: json['tokenExpiry'] == null
      ? null
      : DateTime.parse(json['tokenExpiry'] as String),
  refreshToken: json['refreshToken'] as String,
);

Map<String, dynamic> _$AuthSessionToJson(_AuthSession instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'username': instance.username,
      'fullName': instance.fullName,
      'role': instance.role,
      'roleId': instance.roleId,
      'isAdmin': instance.isAdmin,
      'email': instance.email,
      'phoneNumber': instance.phoneNumber,
      'token': instance.token,
      'tokenExpiry': instance.tokenExpiry?.toIso8601String(),
      'refreshToken': instance.refreshToken,
    };

_MeResponse _$MeResponseFromJson(Map<String, dynamic> json) => _MeResponse(
  userId: (json['userId'] as num).toInt(),
  username: json['username'] as String? ?? '',
  fullName: json['fullName'] as String? ?? '',
  email: json['email'] as String?,
  phoneNumber: json['phoneNumber'] as String?,
  role: json['role'] as String? ?? '',
  isPlatformAdmin: json['isPlatformAdmin'] as bool? ?? false,
  isAccount: json['isAccount'] as bool? ?? false,
);

Map<String, dynamic> _$MeResponseToJson(_MeResponse instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'username': instance.username,
      'fullName': instance.fullName,
      'email': instance.email,
      'phoneNumber': instance.phoneNumber,
      'role': instance.role,
      'isPlatformAdmin': instance.isPlatformAdmin,
      'isAccount': instance.isAccount,
    };
