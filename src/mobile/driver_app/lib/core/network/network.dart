import 'package:dio/dio.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({String baseUrl = 'https://api.redtaxis.com/api/v2/'}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // TODO: Retrieve token from secure storage and append it
          // final token = await SecureStorage.getToken();
          // if (token != null) {
          //   options.headers['Authorization'] = 'Bearer $token';
          // }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // TODO: Intercept 401 errors to perform queued token refresh rotation
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
