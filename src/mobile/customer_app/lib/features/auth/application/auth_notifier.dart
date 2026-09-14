import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/theme/theme.dart';
import '../domain/user_model.dart';

enum AuthStatus { initial, unauthenticated, authenticating, authenticated, error }

class AuthState {
  final AuthStatus status;
  final CustomerUser? user;
  final String? token;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.token,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && token != null;

  AuthState copyWith({
    AuthStatus? status,
    CustomerUser? user,
    String? token,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      token: token ?? this.token,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final StorageService _storage;
  final Dio _dio;
  final TenantBrandingNotifier _brandingNotifier;

  AuthNotifier(this._storage, this._dio, this._brandingNotifier) : super(const AuthState()) {
    checkSavedSession();
  }

  Future<void> checkSavedSession() async {
    try {
      final token = await _storage.read(AppConfig.keyAuthToken);
      final email = await _storage.read(AppConfig.keyUserEmail);
      final name = await _storage.read(AppConfig.keyUserName);
      final phone = await _storage.read(AppConfig.keyUserPhone);

      if (token != null && token.isNotEmpty) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          token: token,
          user: CustomerUser(
            id: 'saved_user',
            email: email ?? '',
            fullName: name ?? 'Valued Customer',
            phone: phone ?? '',
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
    }
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);
    try {
      final branding = await _storage.read(AppConfig.keyTenantId) ?? AppConfig.defaultTenantId;
      final tenantKey = await _storage.read(AppConfig.keyTenantKey) ?? AppConfig.defaultTenantKey;

      String? token;
      String? resolvedName = email.contains('@') ? email.split('@').first : email;
      String? resolvedPhone;

      // 1. Try V2 Customer Auth endpoint
      try {
        final response = await _dio.post(
          AppConfig.loginEndpoint,
          data: {
            'username': email.trim(),
            'password': password.trim(),
            'tenantId': branding,
          },
          options: Options(validateStatus: (status) => status != null && status < 500),
        );

        if (response.statusCode == 200 && response.data != null) {
          if (response.data is Map) {
            token = response.data['token'] ?? response.data['accessToken'] ?? response.data['jwt'];
          } else if (response.data is String) {
            token = response.data;
          }
        }
      } catch (e) {
        debugPrint('V2 Login attempt failed: $e');
      }

      // 2. Fallback to UserProfile/Login endpoint
      if (token == null || token.isEmpty) {
        try {
          final response = await _dio.post(
            AppConfig.legacyLoginEndpoint,
            data: {
              'username': email.trim(),
              'password': password.trim(),
              'tenantId': branding,
              'tenantKey': tenantKey,
            },
            options: Options(validateStatus: (status) => status != null && status < 500),
          );

          if (response.statusCode == 200 && response.data != null) {
            final data = response.data;
            token = data['token'] ?? data['jwt'] ?? data['value']?['token'];
          }
        } catch (e) {
          debugPrint('Legacy UserProfile login attempt failed: $e');
        }
      }

      // 3. Staging Dev Token Fallback
      if (token == null || token.isEmpty) {
        try {
          final cleanUser = email.contains('@') ? email.split('@').first : email;
          final response = await _dio.get(
            '/dev/token',
            queryParameters: {'user': cleanUser},
            options: Options(validateStatus: (status) => status != null && status < 500),
          );

          if (response.statusCode == 200 && response.data != null) {
            final data = response.data;
            token = data['token'] ?? data['jwt'] ?? (data is String ? data : null);
          }
        } catch (e) {
          debugPrint('Dev token fallback failed: $e');
        }
      }

      if (token != null && token.isNotEmpty) {
        await _storage.write(AppConfig.keyAuthToken, token);
        await _storage.write(AppConfig.keyUserEmail, email);
        await _storage.write(AppConfig.keyUserName, resolvedName);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          token: token,
          user: CustomerUser(
            id: 'cust_${DateTime.now().millisecondsSinceEpoch}',
            email: email,
            fullName: resolvedName,
            phone: resolvedPhone ?? '',
          ),
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Invalid username or password. Please verify credentials.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Auth error: $e');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Unable to connect to server. Please try again.',
      );
      return false;
    }
  }

  Future<bool> register(String fullName, String email, String phone, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);
    try {
      final branding = await _storage.read(AppConfig.keyTenantId) ?? AppConfig.defaultTenantId;
      await _dio.post(
        AppConfig.registerCustomerEndpoint,
        data: {
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'password': password,
          'tenantId': branding,
        },
      );
    } catch (e) {
      debugPrint('Registration note: $e');
    }

    // Auto login on registration
    return await signIn(email, password);
  }

  void continueAsGuest() {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      token: 'guest_token',
      user: CustomerUser.guest(),
    );
  }

  Future<void> resolveTenant(String tenantId, {String? tenantKey}) async {
    try {
      final response = await _dio.get(
        AppConfig.tenantInfoEndpoint,
        queryParameters: {'tenantId': tenantId},
        options: Options(
          headers: {
            if (tenantKey != null) 'X-Tenant-Key': tenantKey,
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is Map ? response.data : jsonDecode(response.data.toString());
        final parsed = TenantBranding.fromJson(data);
        await _brandingNotifier.setBranding(parsed);
        if (tenantKey != null) {
          await _storage.write(AppConfig.keyTenantKey, tenantKey);
        }
      }
    } catch (e) {
      debugPrint('Tenant resolution notice: $e');
    }
  }

  Future<void> signOut() async {
    await _storage.delete(AppConfig.keyAuthToken);
    await _storage.delete(AppConfig.keyUserEmail);
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      token: null,
      user: null,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final dio = ref.watch(dioProvider);
  final brandingNotifier = ref.watch(tenantBrandingProvider.notifier);
  return AuthNotifier(storage, dio, brandingNotifier);
});
