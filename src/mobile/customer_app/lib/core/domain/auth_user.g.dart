// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthUser _$AuthUserFromJson(Map<String, dynamic> json) => _AuthUser(
  userId: (json['userId'] as num).toInt(),
  username: json['username'] as String,
  fullName: json['fullName'] as String,
  email: json['email'] as String?,
  phoneNumber: json['phoneNumber'] as String?,
  role: json['role'] as String? ?? '',
  isPlatformAdmin: json['isPlatformAdmin'] as bool? ?? false,
  isAccount: json['isAccount'] as bool? ?? false,
);

Map<String, dynamic> _$AuthUserToJson(_AuthUser instance) => <String, dynamic>{
  'userId': instance.userId,
  'username': instance.username,
  'fullName': instance.fullName,
  'email': instance.email,
  'phoneNumber': instance.phoneNumber,
  'role': instance.role,
  'isPlatformAdmin': instance.isPlatformAdmin,
  'isAccount': instance.isAccount,
};
