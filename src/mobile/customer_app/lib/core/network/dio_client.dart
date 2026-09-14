import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'network_log.dart';

/// Set true when a refresh fails (reuse/expiry) — the router redirects to
/// sign-in. The in-progress booking is preserved by the booking controller.
final sessionExpiredProvider = StateProvider<bool>((ref) => false);

/// Builds the app's single configured [Dio]. Adds the bearer token, performs
/// single-flight refresh on 401, and maps errors to [ApiException].
class DioClient {
  DioClient({
    required this.config,
    required this.tokenStorage,
    required this.onSessionExpired,
  }) {
    dio = Dio(BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onResponse: _onResponse,
      onError: _onError,
    ));
  }

  final AppConfig config;
  final TokenStorage tokenStorage;
  final void Function() onSessionExpired;

  late final Dio dio;

  String? _accessToken;
  Future<bool>? _refreshing; // single-flight guard

  Future<void> setTokens(
      {required String access, required String refresh}) async {
    _accessToken = access;
    await tokenStorage.saveTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> clear() async {
    _accessToken = null;
    await tokenStorage.clear();
  }

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    NetworkLog.markStart(options);
    if (config.tenantKey.isNotEmpty && options.headers['X-Tenant-Key'] == null) {
      options.headers['X-Tenant-Key'] = config.tenantKey;
    }
    if (config.tenantOrgId.isNotEmpty && options.headers['X-Tenant-Id'] == null) {
      options.headers['X-Tenant-Id'] = config.tenantOrgId;
    }
    _accessToken ??= await tokenStorage.readAccessToken();
    if (_accessToken != null && options.headers['Authorization'] == null) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }
    NetworkLog.request(options);
    handler.next(options);
  }

  void _onResponse(Response<dynamic> res, ResponseInterceptorHandler handler) {
    NetworkLog.response(res);
    handler.next(res);
  }

  Future<void> _onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final isAuthCall = err.requestOptions.path.contains('/auth/') ||
        err.requestOptions.path.contains('/customer-auth/');
    if (err.response?.statusCode == 401 && !isAuthCall) {
      final ok = await _runRefresh();
      if (ok) {
        try {
          final clone = await _retry(err.requestOptions);
          return handler.resolve(clone);
        } catch (_) {/* fall through to error mapping below */}
      } else {
        onSessionExpired();
      }
    }
    final mapped = _mapError(err);
    final api = mapped.error;
    NetworkLog.error(
      err,
      code: api is ApiException ? api.code : null,
      message: api is ApiException ? api.message : null,
    );
    handler.next(mapped);
  }

  /// Shares one in-flight refresh across concurrent 401s.
  Future<bool> _runRefresh() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _refresh() async {
    final refresh = await tokenStorage.readRefreshToken();
    final access = _accessToken ?? await tokenStorage.readAccessToken();
    if (refresh == null || access == null) return false;
    try {
      // Bare client so this request itself is never intercepted.
      final bare = Dio(BaseOptions(
        baseUrl: config.apiBaseUrl,
        headers: {
          if (config.tenantKey.isNotEmpty) 'X-Tenant-Key': config.tenantKey,
          if (config.tenantOrgId.isNotEmpty) 'X-Tenant-Id': config.tenantOrgId,
        },
      ));
      final res = await bare.post('/api/v2/customer-auth/refresh', data: {
        'token': access,
        'refreshToken': refresh,
      });
      // Tolerate both the raw shape and the v2 envelope { success, data, errors }.
      final body = res.data as Map<String, dynamic>;
      final data = (body['data'] is Map<String, dynamic>)
          ? body['data'] as Map<String, dynamic>
          : body;
      final newAccess = data['token'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newAccess == null || newRefresh == null) return false;
      await setTokens(access: newAccess, refresh: newRefresh);
      return true;
    } catch (_) {
      await clear();
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions req) {
    return dio.request(
      req.path,
      data: req.data,
      queryParameters: req.queryParameters,
      options: Options(method: req.method, headers: {
        ...req.headers,
        'Authorization': 'Bearer $_accessToken',
      }),
    );
  }

  DioException _mapError(DioException err) {
    final res = err.response;
    String? rawMessage;
    String? code;
    if (res != null) {
      final body = res.data;
      if (body is Map) {
        final errors = body['errors'];
        if (errors is List && errors.isNotEmpty) {
          // v2 envelope errors are { code, message } objects.
          final first = errors.first;
          if (first is Map && first['message'] != null) {
            rawMessage = first['message'].toString();
            code = first['code']?.toString();
          } else {
            rawMessage = first.toString();
          }
        } else if (body['message'] is String) {
          rawMessage = body['message'] as String;
        } else if (body['error'] is String) {
          rawMessage = body['error'] as String;
        }
        // Fallback ONLY — must not clobber a code already read from errors[].
        // (This unconditional overwrite was the bug behind "(400, null)".)
        code ??= body['code']?.toString();
      } else if (body is String && body.isNotEmpty) {
        rawMessage = body;
      }
    }

    // The backend frequently puts a machine code into errors[0].message
    // (e.g. "SESSION_REQUIRED"). Treat an ALL-CAPS token as a code so we can
    // keep it on the exception for logs AND never show it raw to the user.
    final messageIsCode = rawMessage != null && _looksLikeCode(rawMessage);
    final effectiveCode = code ?? (messageIsCode ? rawMessage : null);

    final String userMessage;
    if (res == null) {
      // No response → connection/timeout/socket. Retryable "offline".
      userMessage = 'No connection. Check your internet and try again.';
    } else if (effectiveCode != null && _friendlyMessages.containsKey(effectiveCode)) {
      userMessage = _friendlyMessages[effectiveCode]!;
    } else if (rawMessage != null && !messageIsCode) {
      userMessage = rawMessage; // a genuine human-readable message from the API
    } else {
      userMessage = _genericForStatus(res.statusCode);
    }

    return err.copyWith(
      error: ApiException(userMessage,
          statusCode: res?.statusCode, code: effectiveCode),
    );
  }

  static bool _looksLikeCode(String s) =>
      RegExp(r'^[A-Z][A-Z0-9_]{2,}$').hasMatch(s.trim());

  static String _genericForStatus(int? status) {
    switch (status) {
      case 401:
      case 403:
        return 'Please sign in and try again.';
      case 404:
        return "That wasn't found. Please try again.";
    }
    if (status != null && status >= 500) {
      return 'The service is having trouble. Please try again shortly.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// Known machine codes → friendly, user-safe copy. Anything not listed falls
  /// back to the API's own message (if human) or a status-based generic, so a
  /// raw code is never shown on screen.
  static const Map<String, String> _friendlyMessages = {
    'SESSION_REQUIRED': 'Could not load that address. Please try again.',
    'RESOLVE_FAILED': 'Could not load that address. Please try again.',
    'SEARCH_FAILED': 'Address search is unavailable right now. Please try again.',
    'QUERY_TOO_SHORT': 'Keep typing to search for an address.',
    'LOOKUP_FAILED': 'Could not look up that postcode. Please try again.',
    'MISSING_ID': 'Could not load that address. Please try again.',
    'UNKNOWN_ID_FORMAT': 'Could not load that address. Please try again.',
  };
}

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    config: AppConfig.fromEnvironment(),
    tokenStorage: ref.watch(tokenStorageProvider),
    onSessionExpired: () =>
        ref.read(sessionExpiredProvider.notifier).state = true,
  );
});

/// Convenience accessor for the configured Dio.
final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);
