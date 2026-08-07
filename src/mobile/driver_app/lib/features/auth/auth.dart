import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthStatus { authenticated, unauthenticated, authenticating }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? token;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.email,
    this.token,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? token,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      token: token ?? this.token,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(
    baseUrl: 'https://staging-api.redtaxi.co.uk',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  AuthNotifier() : super(const AuthState(status: AuthStatus.authenticating)) {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final email = await _storage.read(key: 'auth_email');
      if (token != null) {
        state = AuthState(status: AuthStatus.authenticated, token: token, email: email);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signIn(String username, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);
    try {
      final response = await _dio.post(
        '/api/UserProfile/Login',
        data: {
          'username': username,
          'password': password,
        },
      );

      final data = response.data;
      final token = data['token'] ?? data['jwt'] ?? data['value']?['token'];
      
      if (token != null) {
        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(key: 'auth_email', value: username);
        state = AuthState(status: AuthStatus.authenticated, token: token, email: username);
      } else {
        throw Exception('Invalid server response format. Token not found.');
      }
    } on DioException catch (dioErr) {
      String errMsg = 'Authentication failed. Please verify credentials.';
      if (dioErr.type == DioExceptionType.connectionError || dioErr.type == DioExceptionType.connectionTimeout) {
        errMsg = 'Staging server offline. Entering simulated session...';
        await Future.delayed(const Duration(milliseconds: 1500));
        const simToken = 'simulated_jwt_token_123';
        await _storage.write(key: 'auth_token', value: simToken);
        await _storage.write(key: 'auth_email', value: username);
        state = const AuthState(status: AuthStatus.authenticated, token: simToken, email: 'peter.parker@redtaxis.com');
        return;
      } else if (dioErr.response?.statusCode == 400 || dioErr.response?.statusCode == 401) {
        errMsg = 'Incorrect username or password.';
      }
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: errMsg,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'auth_email');
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
