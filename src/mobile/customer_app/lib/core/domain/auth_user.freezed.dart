// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuthUser {

 int get userId; String get username; String get fullName; String? get email; String? get phoneNumber; String get role; bool get isPlatformAdmin; bool get isAccount;
/// Create a copy of AuthUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthUserCopyWith<AuthUser> get copyWith => _$AuthUserCopyWithImpl<AuthUser>(this as AuthUser, _$identity);

  /// Serializes this AuthUser to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthUser&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.role, role) || other.role == role)&&(identical(other.isPlatformAdmin, isPlatformAdmin) || other.isPlatformAdmin == isPlatformAdmin)&&(identical(other.isAccount, isAccount) || other.isAccount == isAccount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,fullName,email,phoneNumber,role,isPlatformAdmin,isAccount);

@override
String toString() {
  return 'AuthUser(userId: $userId, username: $username, fullName: $fullName, email: $email, phoneNumber: $phoneNumber, role: $role, isPlatformAdmin: $isPlatformAdmin, isAccount: $isAccount)';
}


}

/// @nodoc
abstract mixin class $AuthUserCopyWith<$Res>  {
  factory $AuthUserCopyWith(AuthUser value, $Res Function(AuthUser) _then) = _$AuthUserCopyWithImpl;
@useResult
$Res call({
 int userId, String username, String fullName, String? email, String? phoneNumber, String role, bool isPlatformAdmin, bool isAccount
});




}
/// @nodoc
class _$AuthUserCopyWithImpl<$Res>
    implements $AuthUserCopyWith<$Res> {
  _$AuthUserCopyWithImpl(this._self, this._then);

  final AuthUser _self;
  final $Res Function(AuthUser) _then;

/// Create a copy of AuthUser
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

class _AuthUser implements AuthUser {
  const _AuthUser({required this.userId, required this.username, required this.fullName, this.email, this.phoneNumber, this.role = '', this.isPlatformAdmin = false, this.isAccount = false});
  factory _AuthUser.fromJson(Map<String, dynamic> json) => _$AuthUserFromJson(json);

@override final  int userId;
@override final  String username;
@override final  String fullName;
@override final  String? email;
@override final  String? phoneNumber;
@override@JsonKey() final  String role;
@override@JsonKey() final  bool isPlatformAdmin;
@override@JsonKey() final  bool isAccount;

/// Create a copy of AuthUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthUserCopyWith<_AuthUser> get copyWith => __$AuthUserCopyWithImpl<_AuthUser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthUserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthUser&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.username, username) || other.username == username)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.role, role) || other.role == role)&&(identical(other.isPlatformAdmin, isPlatformAdmin) || other.isPlatformAdmin == isPlatformAdmin)&&(identical(other.isAccount, isAccount) || other.isAccount == isAccount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,username,fullName,email,phoneNumber,role,isPlatformAdmin,isAccount);

@override
String toString() {
  return 'AuthUser(userId: $userId, username: $username, fullName: $fullName, email: $email, phoneNumber: $phoneNumber, role: $role, isPlatformAdmin: $isPlatformAdmin, isAccount: $isAccount)';
}


}

/// @nodoc
abstract mixin class _$AuthUserCopyWith<$Res> implements $AuthUserCopyWith<$Res> {
  factory _$AuthUserCopyWith(_AuthUser value, $Res Function(_AuthUser) _then) = __$AuthUserCopyWithImpl;
@override @useResult
$Res call({
 int userId, String username, String fullName, String? email, String? phoneNumber, String role, bool isPlatformAdmin, bool isAccount
});




}
/// @nodoc
class __$AuthUserCopyWithImpl<$Res>
    implements _$AuthUserCopyWith<$Res> {
  __$AuthUserCopyWithImpl(this._self, this._then);

  final _AuthUser _self;
  final $Res Function(_AuthUser) _then;

/// Create a copy of AuthUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? username = null,Object? fullName = null,Object? email = freezed,Object? phoneNumber = freezed,Object? role = null,Object? isPlatformAdmin = null,Object? isAccount = null,}) {
  return _then(_AuthUser(
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
