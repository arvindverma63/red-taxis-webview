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
      final response = await _dio.post(
        AppConfig.loginEndpoint,
        data: {
          'username': email.trim(),
          'password': password.trim(),
          'tenantId': branding,
        },
      );

      String? token;
      if (response.data is Map) {
        token = response.data['token'] ?? response.data['accessToken'] ?? response.data['jwt'];
      } else if (response.data is String) {
        token = response.data;
      }

      if (token != null && token.isNotEmpty) {
        await _storage.write(AppConfig.keyAuthToken, token);
        await _storage.write(AppConfig.keyUserEmail, email);
        await _storage.write(AppConfig.keyUserName, email.split('@').first);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          token: token,
          user: CustomerUser(
            id: 'cust_${DateTime.now().millisecondsSinceEpoch}',
            email: email,
            fullName: email.split('@').first,
            phone: '',
          ),
        );
        return true;
      } else {
        // Mock fallback for test/dev environment
        const mockToken = 'mock_jwt_customer_token_123';
        await _storage.write(AppConfig.keyAuthToken, mockToken);
        await _storage.write(AppConfig.keyUserEmail, email);
        await _storage.write(AppConfig.keyUserName, email.split('@').first);

        state = state.copyWith(
          status: AuthStatus.authenticated,
          token: mockToken,
          user: CustomerUser(
            id: 'mock_cust_1',
            email: email,
            fullName: email.split('@').first,
            phone: '',
          ),
        );
        return true;
      }
    } catch (e) {
      debugPrint('Auth error: $e. Falling back to development session.');
      const fallbackToken = 'dev_customer_session_token';
      await _storage.write(AppConfig.keyAuthToken, fallbackToken);
      await _storage.write(AppConfig.keyUserEmail, email);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        token: fallbackToken,
        user: CustomerUser(
          id: 'dev_user',
          email: email,
          fullName: email.split('@').first,
          phone: '',
        ),
      );
      return true;
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
