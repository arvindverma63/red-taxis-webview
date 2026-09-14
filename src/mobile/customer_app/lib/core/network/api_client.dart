import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../storage/storage_service.dart';
import '../theme/theme.dart';

class ApiClient {
  final Dio dio;

  ApiClient(this.dio);
}

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final branding = ref.watch(tenantBrandingProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final path = options.path.toLowerCase();
        final isAuthEndpoint = path.contains('login') ||
            path.contains('register') ||
            path.contains('tenant-info') ||
            path.contains('token') ||
            path.contains('public');

        if (!isAuthEndpoint) {
          final token = await storage.read(AppConfig.keyAuthToken);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }

        final tenantKey = await storage.read(AppConfig.keyTenantKey) ?? AppConfig.defaultTenantKey;
        options.headers['X-Tenant-Key'] = tenantKey;
        options.headers['X-Tenant-ID'] = branding.tenantId;

        if (kDebugMode) {
          debugPrint('🌐 [HTTP REQUEST] ${options.method} -> ${options.uri}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint('✅ [HTTP RESPONSE] ${response.statusCode} <- ${response.requestOptions.uri}');
        }
        return handler.next(response);
      },
      onError: (DioException error, handler) {
        if (kDebugMode) {
          debugPrint('❌ [HTTP ERROR] ${error.response?.statusCode} <- ${error.requestOptions.uri}: ${error.message}');
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});
