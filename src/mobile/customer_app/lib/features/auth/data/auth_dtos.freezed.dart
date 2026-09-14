// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_dtos.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuthSession {

 int get userId; String get username; String get fullName; String get role; int? get roleId; bool get isAdmin; String? get email; String? get phoneNumber; String get token; DateTime? get tokenExpiry; String get refreshToken;
/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSessionCopyWith<AuthSession> get copyWith => _$AuthSessionCopyWithImpl<AuthSession>(this as AuthSession, _$identity);

  /// Serializes this AuthSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSession&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.role, role) || other.role == role)&&(identical(other.roleId, roleId) || other.roleId == roleId)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.email, email) || other.email == email)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.token, token) || other.token == token)&&(identical(other.tokenExpiry, tokenExpiry) || other.tokenExpiry == tokenExpiry)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,fullName,role,roleId,isAdmin,email,phoneNumber,token,tokenExpiry,refreshToken);

@override
String toString() {
  return 'AuthSession(userId: $userId, username: $username, fullName: $fullName, role: $role, roleId: $roleId, isAdmin: $isAdmin, email: $email, phoneNumber: $phoneNumber, token: $token, tokenExpiry: $tokenExpiry, refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class $AuthSessionCopyWith<$Res>  {
  factory $AuthSessionCopyWith(AuthSession value, $Res Function(AuthSession) _then) = _$AuthSessionCopyWithImpl;
@useResult
$Res call({
 int userId, String username, String fullName, String role, int? roleId, bool isAdmin, String? email, String? phoneNumber, String token, DateTime? tokenExpiry, String refreshToken
});




}
/// @nodoc
class _$AuthSessionCopyWithImpl<$Res>
    implements $AuthSessionCopyWith<$Res> {
  _$AuthSessionCopyWithImpl(this._self, this._then);

  final AuthSession _self;
  final $Res Function(AuthSession) _then;

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? username = null,Object? fullName = null,Object? role = null,Object? roleId = freezed,Object? isAdmin = null,Object? email = freezed,Object? phoneNumber = freezed,Object? token = null,Object? tokenExpiry = freezed,Object? refreshToken = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,roleId: freezed == roleId ? _self.roleId : roleId // ignore: cast_nullable_to_non_nullable
as int?,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,tokenExpiry: freezed == tokenExpiry ? _self.tokenExpiry : tokenExpiry // ignore: cast_nullable_to_non_nullable
as DateTime?,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _AuthSession implements AuthSession {
  const _AuthSession({required this.userId, required this.username, this.fullName = '', this.role = '', this.roleId, this.isAdmin = false, this.email, this.phoneNumber, required this.token, this.tokenExpiry, required this.refreshToken});
  factory _AuthSession.fromJson(Map<String, dynamic> json) => _$AuthSessionFromJson(json);

@override final  int userId;
@override final  String username;
@override@JsonKey() final  String fullName;
@override@JsonKey() final  String role;
@override final  int? roleId;
@override@JsonKey() final  bool isAdmin;
@override final  String? email;
@override final  String? phoneNumber;
@override final  String token;
@override final  DateTime? tokenExpiry;
@override final  String refreshToken;

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthSessionCopyWith<_AuthSession> get copyWith => __$AuthSessionCopyWithImpl<_AuthSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthSession&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.role, role) || other.role == role)&&(identical(other.roleId, roleId) || other.roleId == roleId)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.email, email) || other.email == email)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.token, token) || other.token == token)&&(identical(other.tokenExpiry, tokenExpiry) || other.tokenExpiry == tokenExpiry)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,fullName,role,roleId,isAdmin,email,phoneNumber,token,tokenExpiry,refreshToken);

@override
String toString() {
  return 'AuthSession(userId: $userId, username: $username, fullName: $fullName, role: $role, roleId: $roleId, isAdmin: $isAdmin, email: $email, phoneNumber: $phoneNumber, token: $token, tokenExpiry: $tokenExpiry, refreshToken: $refreshToken)';
}


}

/// @nodoc
abstract mixin class _$AuthSessionCopyWith<$Res> implements $AuthSessionCopyWith<$Res> {
  factory _$AuthSessionCopyWith(_AuthSession value, $Res Function(_AuthSession) _then) = __$AuthSessionCopyWithImpl;
@override @useResult
$Res call({
 int userId, String username, String fullName, String role, int? roleId, bool isAdmin, String? email, String? phoneNumber, String token, DateTime? tokenExpiry, String refreshToken
});




}
/// @nodoc
class __$AuthSessionCopyWithImpl<$Res>
    implements _$AuthSessionCopyWith<$Res> {
  __$AuthSessionCopyWithImpl(this._self, this._then);

  final _AuthSession _self;
  final $Res Function(_AuthSession) _then;

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? username = null,Object? fullName = null,Object? role = null,Object? roleId = freezed,Object? isAdmin = null,Object? email = freezed,Object? phoneNumber = freezed,Object? token = null,Object? tokenExpiry = freezed,Object? refreshToken = null,}) {
  return _then(_AuthSession(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,roleId: freezed == roleId ? _self.roleId : roleId // ignore: cast_nullable_to_non_nullable
as int?,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,tokenExpiry: freezed == tokenExpiry ? _self.tokenExpiry : tokenExpiry // ignore: cast_nullable_to_non_nullable
as DateTime?,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MeResponse {

 int get userId; String get username; String get fullName; String? get email; String? get phoneNumber; String get role; bool get isPlatformAdmin; bool get isAccount;
/// Create a copy of MeResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MeResponseCopyWith<MeResponse> get copyWith => _$MeResponseCopyWithImpl<MeResponse>(this as MeResponse, _$identity);

  /// Serializes this MeResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MeResponse&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.role, role) || other.role == role)&&(identical(other.isPlatformAdmin, isPlatformAdmin) || other.isPlatformAdmin == isPlatformAdmin)&&(identical(other.isAccount, isAccount) || other.isAccount == isAccount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,fullName,email,phoneNumber,role,isPlatformAdmin,isAccount);

@override
String toString() {
  return 'MeResponse(userId: $userId, username: $username, fullName: $fullName, email: $email, phoneNumber: $phoneNumber, role: $role, isPlatformAdmin: $isPlatformAdmin, isAccount: $isAccount)';
}


}

/// @nodoc
abstract mixin class $MeResponseCopyWith<$Res>  {
  factory $MeResponseCopyWith(MeResponse value, $Res Function(MeResponse) _then) = _$MeResponseCopyWithImpl;
@useResult
$Res call({
 int userId, String username, String fullName, String? email, String? phoneNumber, String role, bool isPlatformAdmin, bool isAccount
});




}
/// @nodoc
class _$MeResponseCopyWithImpl<$Res>
    implements $MeResponseCopyWith<$Res> {
  _$MeResponseCopyWithImpl(this._self, this._then);

  final MeResponse _self;
  final $Res Function(MeResponse) _then;

/// Create a copy of MeResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? username = null,Object? fullName = null,Object? email = freezed,Object? phoneNumber = freezed,Object? role = null,Object? isPlatformAdmin = null,Object? isAccount = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,isPlatformAdmin: null == isPlatformAdmin ? _self.isPlatformAdmin : isPlatformAdmin // ignore: cast_nullable_to_non_nullable
as bool,isAccount: null == isAccount ? _self.isAccount : isAccount // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _MeResponse implements MeResponse {
  const _MeResponse({required this.userId, this.username = '', this.fullName = '', this.email, this.phoneNumber, this.role = '', this.isPlatformAdmin = false, this.isAccount = false});
  factory _MeResponse.fromJson(Map<String, dynamic> json) => _$MeResponseFromJson(json);

@override final  int userId;
@override@JsonKey() final  String username;
@override@JsonKey() final  String fullName;
@override final  String? email;
@override final  String? phoneNumber;
@override@JsonKey() final  String role;
@override@JsonKey() final  bool isPlatformAdmin;
@override@JsonKey() final  bool isAccount;

/// Create a copy of MeResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MeResponseCopyWith<_MeResponse> get copyWith => __$MeResponseCopyWithImpl<_MeResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MeResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MeResponse&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.role, role) || other.role == role)&&(identical(other.isPlatformAdmin, isPlatformAdmin) || other.isPlatformAdmin == isPlatformAdmin)&&(identical(other.isAccount, isAccount) || other.isAccount == isAccount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,fullName,email,phoneNumber,role,isPlatformAdmin,isAccount);

@override
String toString() {
  return 'MeResponse(userId: $userId, username: $username, fullName: $fullName, email: $email, phoneNumber: $phoneNumber, role: $role, isPlatformAdmin: $isPlatformAdmin, isAccount: $isAccount)';
}


}

/// @nodoc
abstract mixin class _$MeResponseCopyWith<$Res> implements $MeResponseCopyWith<$Res> {
  factory _$MeResponseCopyWith(_MeResponse value, $Res Function(_MeResponse) _then) = __$MeResponseCopyWithImpl;
@override @useResult
$Res call({
 int userId, String username, String fullName, String? email, String? phoneNumber, String role, bool isPlatformAdmin, bool isAccount
});




}
/// @nodoc
class __$MeResponseCopyWithImpl<$Res>
    implements _$MeResponseCopyWith<$Res> {
  __$MeResponseCopyWithImpl(this._self, this._then);

  final _MeResponse _self;
  final $Res Function(_MeResponse) _then;

/// Create a copy of MeResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? username = null,Object? fullName = null,Object? email = freezed,Object? phoneNumber = freezed,Object? role = null,Object? isPlatformAdmin = null,Object? isAccount = null,}) {
  return _then(_MeResponse(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as int,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,isPlatformAdmin: null == isPlatformAdmin ? _self.isPlatformAdmin : isPlatformAdmin // ignore: cast_nullable_to_non_nullable
as bool,isAccount: null == isAccount ? _self.isAccount : isAccount // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
