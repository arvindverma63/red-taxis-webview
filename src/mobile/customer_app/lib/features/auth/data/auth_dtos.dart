import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_dtos.freezed.dart';
part 'auth_dtos.g.dart';

/// The auth payload returned by `login`, `register-customer` and `refresh`:
/// `{userId, username, fullName, role, roleId, isAdmin, token, tokenExpiry,
/// refreshToken}`. Mapped to the core [AuthUser] + persisted tokens by the
/// repository.
@freezed
abstract class AuthSession with _$AuthSession {
  const factory AuthSession({
    required int userId,
    required String username,
    @Default('') String fullName,
    @Default('') String role,
    int? roleId,
    @Default(false) bool isAdmin,
    String? email,
    String? phoneNumber,
    required String token,
    DateTime? tokenExpiry,
    required String refreshToken,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);
}

/// `GET /api/v2/users/me` — the signed-in user used to restore a session on
/// cold start. Includes `isPlatformAdmin`; account users are flagged via
/// [isAccount] when the backend surfaces it.
@freezed
abstract class MeResponse with _$MeResponse {
  const factory MeResponse({
    required int userId,
    @Default('') String username,
    @Default('') String fullName,
    String? email,
    String? phoneNumber,
    @Default('') String role,
    @Default(false) bool isPlatformAdmin,
    @Default(false) bool isAccount,
  }) = _MeResponse;

  factory MeResponse.fromJson(Map<String, dynamic> json) =>
      _$MeResponseFromJson(json);
}
