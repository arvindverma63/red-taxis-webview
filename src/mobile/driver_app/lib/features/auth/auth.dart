import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:driver_app/core/config/constants.dart';
import 'package:driver_app/core/theme/theme.dart';

enum AuthStatus { authenticated, unauthenticated, authenticating }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? token;
  final String? errorMessage;
  final int? userId;
  final String? tenantId;
  final String? tenantKey;
  final TenantBranding? tenantBranding;
  final bool isTenantConfigured;

  const AuthState({
    required this.status,
    this.email,
    this.token,
    this.errorMessage,
    this.userId,
    this.tenantId,
    this.tenantKey,
    this.tenantBranding,
    this.isTenantConfigured = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? token,
    String? errorMessage,
    int? userId,
    String? tenantId,
    String? tenantKey,
    TenantBranding? tenantBranding,
    bool? isTenantConfigured,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      token: token ?? this.token,
      errorMessage: errorMessage ?? this.errorMessage,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      tenantKey: tenantKey ?? this.tenantKey,
      tenantBranding: tenantBranding ?? this.tenantBranding,
      isTenantConfigured: isTenantConfigured ?? this.isTenantConfigured,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _dio = Dio(BaseOptions(
    baseUrl: 'https://staging-api.redtaxi.co.uk',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  AuthNotifier() : super(const AuthState(status: AuthStatus.authenticating)) {
    // Ignore SSL certificate validation errors for local testing and emulators
    if (!kIsWeb) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[Dio/Auth] $obj'),
      ));
    }
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    try {
      final tenantId = await _storage.read(key: AppConfig.keyTenantId);
      final tenantKey = await _storage.read(key: AppConfig.keyTenantKey);
      final brandingJsonStr = await _storage.read(key: AppConfig.keyTenantBranding);
      
      TenantBranding? branding;
      if (brandingJsonStr != null && brandingJsonStr.isNotEmpty) {
        try {
          branding = TenantBranding.fromJson(jsonDecode(brandingJsonStr));
        } catch (_) {}
      }

      if (branding == null && tenantId != null) {
        branding = _resolveDefaultBrandingForTenant(tenantId, tenantKey ?? '');
      }

      final isConfigured = tenantId != null && tenantId.isNotEmpty;

      final token = await _storage.read(key: AppConfig.keyAuthToken);
      final email = await _storage.read(key: AppConfig.keyAuthEmail);
      final userIdStr = await _storage.read(key: AppConfig.keyAuthUserId);
      final userId = userIdStr != null ? int.tryParse(userIdStr) : null;

      if (token != null && isConfigured) {
        state = AuthState(
          status: AuthStatus.authenticated,
          token: token,
          email: email,
          userId: userId,
          tenantId: tenantId,
          tenantKey: tenantKey,
          tenantBranding: branding,
          isTenantConfigured: true,
        );
        updateFcmToken();
      } else {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          tenantId: tenantId,
          tenantKey: tenantKey,
          tenantBranding: branding,
          isTenantConfigured: isConfigured,
        );
      }
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated, isTenantConfigured: false);
    }
  }

  TenantBranding _resolveDefaultBrandingForTenant(String tenantId, String tenantKey) {
    if (tenantId.toLowerCase().contains('ace')) {
      return TenantBranding.defaultAceTaxis();
    } else if (tenantId.toLowerCase().contains('red')) {
      return TenantBranding.defaultRedTaxis();
    }
    return TenantBranding.defaultFirstTaxis();
  }

  Future<bool> resolveAndSaveTenant(
    String tenantId,
    String tenantKey, {
    TenantBranding? customBranding,
  }) async {
    try {
      TenantBranding resolvedBranding = customBranding ?? _resolveDefaultBrandingForTenant(tenantId, tenantKey);

      // Attempt remote resolution if available
      try {
        final response = await _dio.post(
          '/api/Tenant/Resolve',
          data: {
            'tenantId': tenantId,
            'tenantKey': tenantKey,
          },
          options: Options(
            headers: {'Content-Type': 'application/json', 'Accept': '*/*'},
          ),
        );
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : jsonDecode(response.data.toString());
          resolvedBranding = TenantBranding.fromJson(data);
        }
      } catch (dioErr) {
        debugPrint('[Auth] Remote Tenant/Resolve not available or returned error, using verified branding: $dioErr');
      }

      await _storage.write(key: AppConfig.keyTenantId, value: tenantId);
      await _storage.write(key: AppConfig.keyTenantKey, value: tenantKey);
      await _storage.write(
        key: AppConfig.keyTenantBranding,
        value: jsonEncode(resolvedBranding.toJson()),
      );

      state = state.copyWith(
        tenantId: tenantId,
        tenantKey: tenantKey,
        tenantBranding: resolvedBranding,
        isTenantConfigured: true,
        errorMessage: null,
      );

      return true;
    } catch (e) {
      debugPrint('[Auth] Failed to resolve tenant: $e');
      state = state.copyWith(
        errorMessage: 'Failed to configure fleet: ${e.toString()}',
      );
      return false;
    }
  }

  int? _parseUserIdFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decodedJson = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> claims = jsonDecode(decodedJson);
      final id = claims['id'] ?? claims['sub'] ?? claims['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'];
      if (id != null) {
        return int.tryParse(id.toString());
      }
    } catch (_) {}
    return null;
  }

  Future<void> signIn(String username, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    final activeTenantId = state.tenantId ?? AppConfig.defaultTenantId;
    final activeTenantKey = state.tenantKey ?? AppConfig.defaultTenantKey;

    try {
      debugPrint('[Auth] Sending Login to /api/UserProfile/Login: username=$username, tenantId=$activeTenantId');
      final response = await _dio.post(
        '/api/UserProfile/Login',
        data: {
          'username': username,
          'password': password,
          'tenantId': activeTenantId,
          'tenantKey': activeTenantKey,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': '*/*',
          },
        ),
      );

      final data = response.data;
      final token = data['token'] ?? data['jwt'] ?? data['value']?['token'];
      
      int? userId;
      final userIdObj = data['userId'] ?? data['value']?['userId'];
      if (userIdObj != null) {
        userId = userIdObj is int ? userIdObj : int.tryParse(userIdObj.toString());
      }

      // If backend returns dynamic tenant branding object
      if (data['tenant'] != null || data['tenantBranding'] != null) {
        try {
          final tenantObj = data['tenant'] ?? data['tenantBranding'];
          final dynamicBranding = TenantBranding.fromJson(tenantObj is Map<String, dynamic> ? tenantObj : jsonDecode(tenantObj.toString()));
          await _storage.write(key: AppConfig.keyTenantBranding, value: jsonEncode(dynamicBranding.toJson()));
          state = state.copyWith(tenantBranding: dynamicBranding);
        } catch (_) {}
      }

      if (token != null) {
        userId ??= _parseUserIdFromJwt(token);

        await _storage.write(key: AppConfig.keyAuthToken, value: token);
        await _storage.write(key: AppConfig.keyAuthEmail, value: username);
        if (userId != null) {
          await _storage.write(key: AppConfig.keyAuthUserId, value: userId.toString());
        }
        state = state.copyWith(
          status: AuthStatus.authenticated,
          token: token,
          email: username,
          userId: userId,
        );
        updateFcmToken();
      } else {
        throw Exception('Invalid server response format. Token not found.');
      }
    } on DioException catch (dioErr) {
      String errMsg = 'Authentication failed. Please verify credentials.';
      if (dioErr.type == DioExceptionType.connectionError || dioErr.type == DioExceptionType.connectionTimeout) {
        errMsg = 'Staging server is currently unreachable. Error: ${dioErr.message ?? dioErr.error ?? dioErr.toString()}';
      } else if (dioErr.response?.statusCode == 400 || dioErr.response?.statusCode == 401) {
        errMsg = 'Incorrect username or password for ${state.tenantBranding?.name ?? "this fleet"}.';
      } else if (dioErr.response?.statusCode == 403) {
        errMsg = 'Tenant Key is invalid or expired for ${state.tenantBranding?.name ?? "this fleet"}.';
      }
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: errMsg,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> updateFcmToken() async {
    final token = state.token;
    if (token == null) return;

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      debugPrint('[Auth] Updating FCM Token to backend: $fcmToken');
      final response = await _dio.post(
        '/api/DriverApp/UpdateFCM',
        data: {
          'fcm': fcmToken,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      debugPrint('[Auth] FCM Token update response status: ${response.statusCode}');
    } catch (e) {
      debugPrint('[Auth] Failed to update FCM Token to backend: $e');
    }
  }

  Future<void> signOut() async {
    await _storage.delete(key: AppConfig.keyAuthToken);
    await _storage.delete(key: AppConfig.keyAuthEmail);
    await _storage.delete(key: AppConfig.keyAuthUserId);
    // Retain tenant_id, tenant_key and branding for clean 2-field login
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      token: null,
      email: null,
      userId: null,
      errorMessage: null,
    );
  }

  Future<void> switchTenant() async {
    await _storage.delete(key: AppConfig.keyTenantId);
    await _storage.delete(key: AppConfig.keyTenantKey);
    await _storage.delete(key: AppConfig.keyTenantBranding);
    await _storage.delete(key: AppConfig.keyAuthToken);
    await _storage.delete(key: AppConfig.keyAuthEmail);
    await _storage.delete(key: AppConfig.keyAuthUserId);
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      isTenantConfigured: false,
      tenantId: null,
      tenantKey: null,
      tenantBranding: null,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
