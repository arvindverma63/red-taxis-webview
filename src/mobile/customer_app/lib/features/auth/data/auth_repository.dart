import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/domain/auth_user.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_dtos.dart';

/// Talks to `/api/v2/customer-auth/*` + `/api/v2/users/me`, persists tokens via
/// [DioClient.setTokens], and pushes the resolved [AuthUser] into the core
/// [SessionController]. The application layer ([AuthController]) calls these and
/// surfaces loading / error state — the repository itself stays UI-free.
class AuthRepository {
  AuthRepository(this._ref);

  final Ref _ref;

  Dio get _dio => _ref.read(dioProvider);
  DioClient get _client => _ref.read(dioClientProvider);
  SessionController get _session => _ref.read(sessionProvider.notifier);

  /// Persisted "has the user seen onboarding" flag — first run shows onboarding,
  /// thereafter splash goes straight to sign-in when unauthenticated.
  static const _onboardingSeenKey = 'onboarding_seen';

  // ── Session lifecycle ─────────────────────────────────────────────────

  /// Signs in with username OR email + password. On success persists tokens and
  /// sets the core session user. Throws [ApiException] on failure.
  Future<AuthUser> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/api/v2/customer-auth/login', data: {
        'username': usernameOrEmail,
        'password': password,
      });
      final session = _parseSession(res.data);
      await _applySession(session);
      return _toAuthUser(session);
    } catch (e) {
      // Surface a typed ApiException (the controller catches ApiException; a raw
      // DioException would fall through to a generic message).
      throw _asApiException(e, 'Could not sign you in. Please try again.');
    }
  }

  /// Registers a public customer (B1) via `/api/v2/customer-auth/register-customer` and
  /// signs them in. Real API errors (e.g. "email already exists") propagate as
  /// [ApiException] for the UI to show. Only the preview/offline build falls
  /// back to a synthesized mock session.
  Future<AuthUser> registerCustomer({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/api/v2/customer-auth/register-customer', data: {
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'password': password,
      });
      final session = _parseSession(res.data);
      await _applySession(session);
      return _toAuthUser(session);
    } catch (e) {
      if (AppConfig.previewMocks) {
        return _mockRegister(
          fullName: fullName,
          email: email,
          phoneNumber: phoneNumber,
        );
      }
      throw _asApiException(e, 'Could not create your account. Please try again.');
    }
  }

  /// Normalises a thrown error into an [ApiException] (the dio interceptor
  /// already attaches one to [DioException.error]).
  ApiException _asApiException(Object e, String fallback) {
    if (e is ApiException) return e;
    if (e is DioException) {
      final err = e.error;
      if (err is ApiException) return err;
      return ApiException(e.message ?? fallback, statusCode: e.response?.statusCode);
    }
    return ApiException(fallback);
  }

  /// Restores a session on cold start: if an access token is stored, fetch the
  /// current user from `/api/v2/users/me` and set the session. Returns the user,
  /// or null when there is no valid session (clearing any stale tokens).
  Future<AuthUser?> restoreSession() async {
    final stored = await _ref.read(tokenStorageProvider).readAccessToken();
    if (stored == null || stored.isEmpty) return null;
    try {
      final res = await _dio.get('/api/v2/users/me');
      final me = MeResponse.fromJson(
        unwrapV2(res.data, (d) => d as Map<String, dynamic>),
      );
      final user = AuthUser(
        userId: me.userId,
        username: me.username,
        fullName: me.fullName,
        email: me.email,
        phoneNumber: me.phoneNumber,
        role: me.role,
        isPlatformAdmin: me.isPlatformAdmin,
        isAccount: me.isAccount,
      );
      _session.setUser(user);
      return user;
    } on ApiException {
      // Token invalid/expired beyond refresh — clear and treat as signed out.
      await _client.clear();
      _session.clear();
      return null;
    }
  }

  /// Best-effort API logout (revokes the refresh-token family), then clears
  /// local tokens + session regardless of the call outcome.
  Future<void> logout() async {
    final refresh = await _ref.read(tokenStorageProvider).readRefreshToken();
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _dio.post('/api/v2/customer-auth/logout', data: {'refreshToken': refresh});
      } on ApiException {
        // Best-effort — local sign-out still proceeds.
      }
    }
    await _session.signOut();
  }

  // ── Password / verification (always 200; never reveal account existence) ──
  //
  // Endpoints + payloads match the backend CustomerAuthController contract:
  // forgot-password {email}, reset-password {email, token, newPassword},
  // send-verify-email {email}, verify-email {email, token}. The reset/verify
  // links emailed to the customer deep-link to /reset-password and /verify-email.

  Future<void> forgotPassword(String email) async {
    await _dio.post('/api/v2/customer-auth/forgot-password', data: {
      'email': email,
    });
  }

  /// Completes a password reset with the token from the emailed link.
  Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    await _dio.post('/api/v2/customer-auth/reset-password', data: {
      'email': email,
      'token': token,
      'newPassword': newPassword,
    });
  }

  Future<void> verifyEmail({
    required String email,
    required String token,
  }) async {
    await _dio.post('/api/v2/customer-auth/verify-email', data: {
      'email': email,
      'token': token,
    });
  }

  Future<void> sendVerifyEmail(String email) async {
    await _dio.post('/api/v2/customer-auth/send-verify-email', data: {
      'email': email,
    });
  }

  // ── Onboarding-seen flag ──────────────────────────────────────────────

  Future<bool> hasSeenOnboarding() async {
    final v = await _ref.read(secureStorageProvider).read(key: _onboardingSeenKey);
    return v == 'true';
  }

  Future<void> markOnboardingSeen() async {
    await _ref
        .read(secureStorageProvider)
        .write(key: _onboardingSeenKey, value: 'true');
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /// Login/register/refresh payloads are returned raw (v1 shape) by the backend,
  /// but tolerate a v2 envelope too.
  AuthSession _parseSession(dynamic body) {
    final map = unwrapV2(body, (d) => d as Map<String, dynamic>);
    return AuthSession.fromJson(map);
  }

  Future<void> _applySession(AuthSession session) async {
    await _client.setTokens(
      access: session.token,
      refresh: session.refreshToken,
    );
    _session.setUser(_toAuthUser(session));
  }

  AuthUser _toAuthUser(AuthSession s) => AuthUser(
        userId: s.userId,
        username: s.username,
        fullName: s.fullName,
        email: s.email,
        phoneNumber: s.phoneNumber,
        role: s.role,
        isPlatformAdmin: s.isAdmin,
        isAccount: s.role.toLowerCase() == 'account',
      );

  Future<AuthUser> _mockRegister({
    required String fullName,
    required String email,
    required String phoneNumber,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _client.setTokens(
      access: 'mock-access-$now',
      refresh: 'mock-refresh-$now',
    );
    final user = AuthUser(
      userId: -now ~/ 1000, // negative id flags a mock, never collides with real
      username: email,
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      role: 'Customer',
    );
    _session.setUser(user);
    return user;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(AuthRepository.new);
