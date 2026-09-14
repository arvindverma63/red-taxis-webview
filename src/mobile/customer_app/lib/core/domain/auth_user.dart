import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';
part 'auth_user.g.dart';

/// The signed-in customer. App-wide identity, held by the core session so any
/// feature can read it without importing the auth feature.
@freezed
abstract class AuthUser with _$AuthUser {
  const factory AuthUser({
    required int userId,
    required String username,
    required String fullName,
    String? email,
    String? phoneNumber,
    @Default('') String role,
    @Default(false) bool isPlatformAdmin,
    @Default(false) bool isAccount, // billed-to-account user vs public customer
  }) = _AuthUser;

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      _$AuthUserFromJson(json);
}
