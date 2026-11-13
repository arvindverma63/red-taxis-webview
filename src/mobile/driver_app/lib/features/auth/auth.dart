import 'package:driver_app/core/logging/remote_logger.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:driver_app/firebase_options.dart';
import 'package:driver_app/core/config/constants.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/features/auth/presentation/widgets/fleet_qr_parser.dart';

enum AuthStatus { authenticated, unauthenticated, authenticating }

/// Outcome of refreshing the fleet's branding from the server.
enum BrandingSyncResult {
  /// New colours/name/logo were applied.
  updated,

  /// The server's branding matches what the app already shows.
  unchanged,

  /// The server could not be reached or sent an unusable reply; nothing changed.
  failed,

  /// No fleet is configured yet, so there is nothing to sync.
  notConfigured,
}

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
      var tenantId = await _storage.read(key: AppConfig.keyTenantId);
      var tenantKey = await _storage.read(key: AppConfig.keyTenantKey);
      final brandingJsonStr = await _storage.read(key: AppConfig.keyTenantBranding);

      // Repair a fleet saved earlier with the ID and key stuck together in the
      // ID ("org_123:rtk_pub_abc"), which the server rejects.
      if (tenantId != null && tenantId.isNotEmpty) {
        final fixed = normalizeTenantCredentials(tenantId, tenantKey ?? '');
        if (fixed.tenantId != tenantId || fixed.tenantKey != (tenantKey ?? '')) {
          tenantId = fixed.tenantId;
          tenantKey = fixed.tenantKey;
          await _storage.write(key: AppConfig.keyTenantId, value: tenantId);
          await _storage.write(key: AppConfig.keyTenantKey, value: tenantKey);
        }
      }
      
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

      // Pick up any branding the operator changed since the last launch.
      // Fire-and-forget: the stored theme is already showing.
      if (isConfigured) {
        unawaited(syncTenantBranding());
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

  /// Raw `data` object from `GET /api/v2/public/tenant-info`, or null when the
  /// call fails or the reply is unusable.
  Future<Map<String, dynamic>?> _fetchTenantPayload(String tenantId, String tenantKey) async {
    _lastTenantFetchError = null;
    try {
      final headers = <String, dynamic>{
        'Accept': 'application/json',
      };
      if (tenantKey.isNotEmpty) {
        headers['X-Tenant-Key'] = tenantKey;
      }

      debugPrint('[Auth] Querying /api/v2/public/tenant-info?tenantId=$tenantId');
      final response = await _dio.get(
        '/api/v2/public/tenant-info',
        queryParameters: {
          'tenantId': tenantId,
        },
        options: Options(
          headers: headers,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : jsonDecode(response.data.toString()) as Map<String, dynamic>;

        if (data['success'] == true || data['data'] != null) {
          return data['data'] is Map<String, dynamic> ? data['data'] as Map<String, dynamic> : data;
        }
        _lastTenantFetchError = _errorFromBody(data, response.statusCode);
      }
    } catch (e) {
      debugPrint('[Auth] /api/v2/public/tenant-info query failed: $e');
      _lastTenantFetchError = _friendlyTenantError(e);
    }
    return null;
  }

  /// Why the last tenant-info call failed, in words a driver can act on.
  String? _lastTenantFetchError;

  String _errorFromBody(dynamic body, int? status) {
    String? code;
    String? message;
    if (body is Map && body['errors'] is List && (body['errors'] as List).isNotEmpty) {
      final first = (body['errors'] as List).first;
      if (first is Map) {
        code = first['code']?.toString();
        message = first['message']?.toString();
      }
    }
    return tenantErrorMessage(code: code, message: message, status: status);
  }

  String _friendlyTenantError(Object e) {
    if (e is DioException) {
      final offline = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      if (offline && e.response == null) {
        return tenantErrorMessage(offline: true);
      }
      return _errorFromBody(e.response?.data, e.response?.statusCode);
    }
    return tenantErrorMessage();
  }

  /// Plain-language text for a failed fleet lookup (API error code first,
  /// then HTTP status, then connectivity).
  @visibleForTesting
  static String tenantErrorMessage({String? code, String? message, int? status, bool offline = false}) {
    if (offline) {
      return "Can't reach the server. Check your internet connection and try again.";
    }
    switch (code) {
      case 'TENANT_KEY_INVALID':
        return "That tenant access key isn't recognised. Check the key and try again.";
      case 'TENANT_KEY_REQUIRED':
        return 'Enter the tenant access key for this fleet.';
      case 'TENANT_MISMATCH':
        return "That Tenant ID doesn't match the access key. Check both and try again.";
    }
    if (status == 401 || status == 403) {
      return "The Tenant ID or access key wasn't accepted. Check both and try again.";
    }
    if (status == 404) {
      return "We couldn't find that fleet. Check the Tenant ID and try again.";
    }
    if (message != null && message.trim().isNotEmpty) {
      return "Couldn't connect to this fleet: ${message.trim()}";
    }
    return "Couldn't verify this fleet. Check the Tenant ID and key, then try again.";
  }

  /// Built-in demo fleets that have local branding to fall back on. Any other
  /// fleet must be verified by the server — it never silently becomes
  /// "First Taxis".
  static const _presetTenantIds = {
    'org_ace_taxis',
    'org_red_taxis',
    'org_first_taxis',
    'org_first_taxi',
  };

  Future<TenantBranding?> fetchTenantInfo(String tenantId, String tenantKey) async {
    final payload = await _fetchTenantPayload(tenantId, tenantKey);
    if (payload == null) return null;
    try {
      final branding = TenantBranding.fromJson({
        ...payload,
        'tenantId': tenantId,
        'tenantKey': tenantKey,
      }).withAbsoluteLogos(_dio.options.baseUrl).copyWith(syncedAt: DateTime.now());
      debugPrint('[Auth] Successfully resolved company name: ${branding.name}');
      return branding;
    } catch (e) {
      debugPrint('[Auth] Could not read tenant-info payload: $e');
      return null;
    }
  }

  bool _syncingBranding = false;

  /// Re-fetches the fleet's branding (name, colours, logo, contacts) from
  /// `/public/tenant-info` and applies it, so changes the operator makes
  /// later show up in the app without re-scanning the QR code. Runs on app
  /// start and from Settings → "Sync theme now". Never throws; on any failure
  /// the current look is kept.
  Future<BrandingSyncResult> syncTenantBranding() async {
    final tenantId = state.tenantId;
    final tenantKey = state.tenantKey ?? '';
    if (tenantId == null || tenantId.isEmpty) return BrandingSyncResult.notConfigured;
    if (_syncingBranding) return BrandingSyncResult.unchanged;
    _syncingBranding = true;
    try {
      final payload = await _fetchTenantPayload(tenantId, tenantKey);
      if (payload == null) return BrandingSyncResult.failed;

      // Logo paths from the API may be relative ("/uploads/logo.png"); make
      // them full addresses. A blank logo stays null so the default shows.
      var fresh = TenantBranding.fromJson({
        ...payload,
        'tenantId': tenantId,
        'tenantKey': tenantKey,
      }).withAbsoluteLogos(_dio.options.baseUrl);
      final current = state.tenantBranding;

      // A reply with no colours at all must not wipe a good theme back to the
      // generic default: keep the current colours, refresh the rest.
      if (current != null && !TenantBranding.payloadHasColours(payload)) {
        fresh = fresh.copyWith(
          primaryColor: current.primaryColor,
          primaryDarkColor: current.primaryDarkColor,
          primaryLightColor: current.primaryLightColor,
          accentColor: current.accentColor,
          secondaryColor: current.secondaryColor,
          gradientStart: current.gradientStart,
          gradientMid: current.gradientMid,
          gradientEnd: current.gradientEnd,
        );
      }
      fresh = fresh.copyWith(tenantId: tenantId, tenantKey: tenantKey, syncedAt: DateTime.now());

      final changed = current == null || !fresh.sameLookAs(current);
      await _storage.write(
        key: AppConfig.keyTenantBranding,
        value: jsonEncode(fresh.toJson()),
      );
      state = state.copyWith(tenantBranding: fresh);
      return changed ? BrandingSyncResult.updated : BrandingSyncResult.unchanged;
    } catch (e) {
      debugPrint('[Auth] Branding sync failed: $e');
      return BrandingSyncResult.failed;
    } finally {
      _syncingBranding = false;
    }
  }

  Future<bool> resolveAndSaveTenant(
    String tenantId,
    String tenantKey, {
    TenantBranding? customBranding,
  }) async {
    final cleaned = normalizeTenantCredentials(tenantId, tenantKey);
    tenantId = cleaned.tenantId;
    tenantKey = cleaned.tenantKey;
    try {
      TenantBranding? resolvedBranding = customBranding;

      // 1. Attempt remote public tenant-info resolution
      resolvedBranding ??= await fetchTenantInfo(tenantId, tenantKey);

      // 2. Secondary fallback to /api/Tenant/Resolve if not resolved
      if (resolvedBranding == null) {
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
            // Only trust a reply that actually names the fleet.
            final named = data is Map<String, dynamic> &&
                ((data['companyName'] ?? data['name'] ?? (data['data'] is Map ? data['data']['companyName'] : null)) != null);
            if (named) resolvedBranding = TenantBranding.fromJson(data);
          }
        } catch (dioErr) {
          debugPrint('[Auth] Remote Tenant/Resolve not available or returned error: $dioErr');
        }
      }

      // 3. Only the built-in demo fleets may fall back to local branding. For
      // anything else, tell the driver why it failed instead of quietly
      // showing "First Taxis" and saving a fleet that was never verified.
      if (resolvedBranding == null && !_presetTenantIds.contains(tenantId.toLowerCase())) {
        state = state.copyWith(
          errorMessage: _lastTenantFetchError ?? tenantErrorMessage(),
        );
        return false;
      }
      resolvedBranding ??= _resolveDefaultBrandingForTenant(tenantId, tenantKey);

      // Ensure tenantId and tenantKey are populated
      resolvedBranding = resolvedBranding.copyWith(
        tenantId: tenantId,
        tenantKey: tenantKey,
      );

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

  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> updateFcmToken() async {
    final token = state.token;
    if (token == null) return;

    try {
      try {
        if (Firebase.apps.isEmpty) {
          if (defaultTargetPlatform == TargetPlatform.android) {
            await Firebase.initializeApp();
          } else {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
          }
        }
      } catch (fbErr) {
        debugPrint('[Auth] Notice: Firebase initialization error/bypassed: $fbErr');
      }

      // Attach token refresh listener to automatically update backend when APNs/FCM token is issued or refreshed
      _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((refreshedToken) {
        debugPrint('[Auth] FCM Token refreshed asynchronously: $refreshedToken');
        _sendTokenToBackend(refreshedToken, null);
      });

      String? apnsToken;
      String? fcmToken;

      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          // On physical iOS devices, APNs registration with Apple servers is asynchronous and may take 2-5 seconds on startup.
          for (int attempt = 0; attempt < 8; attempt++) {
            try {
              apnsToken = await FirebaseMessaging.instance.getAPNSToken();
              if (apnsToken != null && apnsToken.isNotEmpty) {
                debugPrint('[Auth] APNs Token successfully acquired (attempt ${attempt + 1}): $apnsToken');
                RemoteLogger.info('Push', 'APNs token acquired attempt ${attempt + 1}: ${RemoteLogger.mask(apnsToken)}');
                break;
              }
            } catch (apnsErr) {
              debugPrint('[Auth] APNs token retrieval attempt ${attempt + 1} notice: $apnsErr');
            }
            if (attempt < 7) {
              await Future.delayed(const Duration(milliseconds: 1500));
            }
          }
        }

        try {
          fcmToken = await FirebaseMessaging.instance.getToken();
          debugPrint('[Auth] FCM Token retrieved: $fcmToken');
        } on PlatformException catch (pe) {
          debugPrint('[Auth] FCM getToken PlatformException: $pe');
        } catch (fcmErr) {
          debugPrint('[Auth] FCM getToken notice: $fcmErr');
        }
      } catch (err) {
        debugPrint('[Auth] Token retrieval general notice: $err');
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && (apnsToken == null || apnsToken.isEmpty)) {
        RemoteLogger.error('Push', 'No APNs token after retries (check Push capability / signing / permission). fcm=${RemoteLogger.mask(fcmToken)}');
      }
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _sendTokenToBackend(fcmToken, apnsToken);
      } else if (apnsToken != null && apnsToken.isNotEmpty) {
        // A raw APNs token is not a valid FCM registration token, so storing it
        // would make backend pushes fail silently. Wait for onTokenRefresh to
        // deliver the real FCM token once Firebase can exchange the APNs token.
        RemoteLogger.error('Push', 'APNs token present but FCM token unavailable (APNs key missing in Firebase?): ${RemoteLogger.mask(apnsToken)}');
        debugPrint('[Auth] APNs token acquired but FCM token unavailable; check the APNs key in Firebase Console. Not uploading raw APNs token.');
      } else {
        debugPrint('[Auth] APNs/FCM token is still pending registration with Apple/Firebase.');
      }
    } catch (e) {
      debugPrint('[Auth] Failed to update FCM Token to backend: $e');
    }
  }

  Future<void> _sendTokenToBackend(String primaryToken, String? apnsToken) async {
    final token = state.token;
    if (token == null) return;

    // Backend contract (POST /api/DriverApp/UpdateFCM) only needs the FCM token.
    final payload = <String, dynamic>{'fcm': primaryToken};

    debugPrint('[Auth] Updating FCM & APNs Token to backend: $payload');
    try {
      final response = await _dio.post(
        '/api/DriverApp/UpdateFCM',
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      debugPrint('[Auth] DriverApp/UpdateFCM response status: ${response.statusCode}');
      RemoteLogger.info('Push', 'UpdateFCM status ${response.statusCode} fcm=${RemoteLogger.mask(primaryToken)} apns=${RemoteLogger.mask(apnsToken)}');
    } catch (dErr) {
      RemoteLogger.error('Push', 'UpdateFCM failed: $dErr');
      debugPrint('[Auth] DriverApp/UpdateFCM notice: $dErr, trying UserProfile/UpdateFCM...');
      try {
        final res2 = await _dio.post(
          '/api/UserProfile/UpdateFCM',
          data: payload,
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ),
        );
        debugPrint('[Auth] UserProfile/UpdateFCM response status: ${res2.statusCode}');
      } catch (e2) {
        debugPrint('[Auth] Both FCM update endpoints failed: $e2');
      }
    }
  }

  Future<void> signOut() async {
    await _storage.delete(key: AppConfig.keyAuthToken);
    await _storage.delete(key: AppConfig.keyAuthEmail);
    await _storage.delete(key: AppConfig.keyAuthUserId);
    await _storage.delete(key: 'shift_online');
    await _storage.delete(key: 'shift_start_time');
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
    await _storage.delete(key: 'shift_online');
    await _storage.delete(key: 'shift_start_time');
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
