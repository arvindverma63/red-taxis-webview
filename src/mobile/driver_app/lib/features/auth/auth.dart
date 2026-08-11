import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

enum AuthStatus { authenticated, unauthenticated, authenticating }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? token;
  final String? errorMessage;
  final int? userId;

  const AuthState({
    required this.status,
    this.email,
    this.token,
    this.errorMessage,
    this.userId,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? token,
    String? errorMessage,
    int? userId,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      token: token ?? this.token,
      errorMessage: errorMessage ?? this.errorMessage,
      userId: userId ?? this.userId,
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
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint('[Dio/Auth] $obj'),
    ));
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final email = await _storage.read(key: 'auth_email');
      final userIdStr = await _storage.read(key: 'auth_user_id');
      final userId = userIdStr != null ? int.tryParse(userIdStr) : null;
      if (token != null) {
        state = AuthState(status: AuthStatus.authenticated, token: token, email: email, userId: userId);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
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

    try {
      Response response;
      if (username.toLowerCase() == 'driver' && password == 'driver') {
        // Fetch a real JWT token issued by the dev endpoint on the server
        response = await _dio.get('/dev/token?user=$username');
      } else {
        response = await _dio.post(
          '/api/UserProfile/Login',
          data: {
            'username': username,
            'password': password,
          },
        );
      }

      final data = response.data;
      final token = data['token'] ?? data['jwt'] ?? data['value']?['token'];
      
      int? userId;
      final userIdObj = data['userId'] ?? data['value']?['userId'];
      if (userIdObj != null) {
        userId = userIdObj is int ? userIdObj : int.tryParse(userIdObj.toString());
      }

      if (token != null) {
        userId ??= _parseUserIdFromJwt(token);

        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(key: 'auth_email', value: username);
        if (userId != null) {
          await _storage.write(key: 'auth_user_id', value: userId.toString());
        }
        state = AuthState(
          status: AuthStatus.authenticated,
          token: token,
          email: username,
          userId: userId,
        );
      } else {
        throw Exception('Invalid server response format. Token not found.');
      }
    } on DioException catch (dioErr) {
      String errMsg = 'Authentication failed. Please verify credentials.';
      if (dioErr.type == DioExceptionType.connectionError || dioErr.type == DioExceptionType.connectionTimeout) {
        errMsg = 'Staging server is currently unreachable. Error: ${dioErr.message ?? dioErr.error ?? dioErr.toString()}';
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
    await _storage.delete(key: 'auth_user_id');
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
