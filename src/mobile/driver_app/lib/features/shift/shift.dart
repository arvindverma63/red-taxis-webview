import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:geolocator/geolocator.dart';
import 'package:driver_app/core/location/location.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

enum ShiftStatus { offline, online }

class ShiftState {
  final ShiftStatus status;
  final DateTime? startTime;
  final bool isLoading;

  const ShiftState({
    required this.status,
    this.startTime,
    this.isLoading = false,
  });

  ShiftState copyWith({
    ShiftStatus? status,
    DateTime? startTime,
    bool? isLoading,
  }) {
    return ShiftState(
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ShiftNotifier extends StateNotifier<ShiftState> {
  final Ref _ref;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _heartbeatTimer;
  final _locationService = LocationService();
  DateTime? _lastGpsSendTime;
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final _dio = Dio(BaseOptions(
    baseUrl: 'https://staging-api.redtaxi.co.uk',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  ShiftNotifier(this._ref) : super(const ShiftState(status: ShiftStatus.offline)) {
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
        logPrint: (obj) => debugPrint('[Dio/Shift] $obj'),
      ));
    }
    _restoreShiftState();
  }

  Future<void> _restoreShiftState() async {
    try {
      final isOnlineStr = await _storage.read(key: 'shift_online');
      if (isOnlineStr == 'true') {
        final startTimeStr = await _storage.read(key: 'shift_start_time');
        final startTime = startTimeStr != null ? DateTime.tryParse(startTimeStr) : null;
        
        state = ShiftState(
          status: ShiftStatus.online,
          startTime: startTime ?? DateTime.now(),
        );

        final permResult = await _locationService.checkPermissions();
        if (permResult == LocationPermissionResult.granted) {
          _startLocationTracking();
        }
      }
    } catch (e) {
      debugPrint("[ShiftNotifier] Restore shift state error: $e");
    }
  }

  void _startLocationTracking() {
    _stopLocationTracking();

    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        FlutterBackgroundService().startService();
      } catch (e) {
        debugPrint("[ShiftNotifier] Background service start error: $e");
      }
    }

    final auth = _ref.read(authProvider);
    final fleetName = auth.tenantBranding?.name ?? 'First Taxis';

    try {
      _locationSubscription = _locationService
          .getLocationStream(
            notificationTitle: '$fleetName Online',
            notificationText: 'Streaming live GPS location to dispatch',
          )
          .listen(
            (position) {
              _sendGpsUpdate(position);
            },
            onError: (err) {
              debugPrint("[ShiftNotifier] Location stream error: $err");
            },
          );
    } catch (e) {
      debugPrint("[ShiftNotifier] Location stream setup error: $e");
    }

    // Periodic heartbeat timer (every 10s) ensuring location is sent even when stationary
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (state.status != ShiftStatus.online) return;
      try {
        final pos = await _locationService.getCurrentLocation();
        _sendGpsUpdate(pos);
      } catch (err) {
        debugPrint("[ShiftNotifier] Periodic GPS heartbeat error: $err");
      }
    });
  }

  void _stopLocationTracking() {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        FlutterBackgroundService().invoke('stopService');
      } catch (e) {
        debugPrint("[ShiftNotifier] Background service stop error: $e");
      }
    }
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  String _formatDateTime(DateTime dt) {
    String year = dt.year.toString();
    String month = dt.month.toString().padLeft(2, '0');
    String day = dt.day.toString().padLeft(2, '0');
    String hour = dt.hour.toString().padLeft(2, '0');
    String minute = dt.minute.toString().padLeft(2, '0');
    String second = dt.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  Future<LocationPermissionResult> goOnline() async {
    if (state.isLoading) return LocationPermissionResult.granted;
    state = state.copyWith(isLoading: true);

    try {
      // 1. Verify location service and permissions first
      final permResult = await _locationService.checkPermissions();
      if (permResult != LocationPermissionResult.granted) {
        return permResult;
      }

      // 2. Start continuous background location tracking and periodic heartbeat
      _startLocationTracking();

      // 3. Update state and local storage immediately (Optimistic UI Update)
      state = ShiftState(
        status: ShiftStatus.online,
        startTime: DateTime.now(),
        isLoading: false,
      );
      try {
        await _storage.write(key: 'shift_online', value: 'true');
        await _storage.write(key: 'shift_start_time', value: state.startTime.toString());
      } catch (storageErr) {
        debugPrint("[ShiftNotifier] Storage write error in goOnline: $storageErr");
      }

      // 4. Dispatch the API call in the background
      final auth = _ref.read(authProvider);
      final userId = auth.userId ?? 65;
      final token = auth.token;
      final shiftDate = _formatDateTime(DateTime.now());

      _dio.get(
        '/api/DriverApp/DriverShift',
        queryParameters: {
          'userid': userId,
          'status': 1000, // AppDriverShift.Start (Online)
          'shiftDate': shiftDate,
        },
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      ).then((_) {
        debugPrint("[ShiftNotifier] GoOnline API success");
      }).catchError((e) {
        debugPrint("[ShiftNotifier] GoOnline API background error: $e");
      });

      return LocationPermissionResult.granted;
    } finally {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> goOffline() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);

    try {
      // 1. Immediately cancel location tracking and heartbeat
      _stopLocationTracking();

      // 2. Update state and local storage immediately (Optimistic UI Update)
      state = const ShiftState(status: ShiftStatus.offline, isLoading: false);
      try {
        await _storage.write(key: 'shift_online', value: 'false');
        await _storage.delete(key: 'shift_start_time');
      } catch (storageErr) {
        debugPrint("[ShiftNotifier] Storage write error in goOffline: $storageErr");
      }

      // 3. Dispatch the API call in the background
      final auth = _ref.read(authProvider);
      final userId = auth.userId ?? 65;
      final token = auth.token;
      final shiftDate = _formatDateTime(DateTime.now());

      _dio.get(
        '/api/DriverApp/DriverShift',
        queryParameters: {
          'userid': userId,
          'status': 1001, // AppDriverShift.Finish (Offline)
          'shiftDate': shiftDate,
        },
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      ).then((_) {
        debugPrint("[ShiftNotifier] GoOffline API success");
      }).catchError((e) {
        debugPrint("[ShiftNotifier] GoOffline API background error: $e");
      });
    } finally {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> _sendGpsUpdate(Position position) async {
    final now = DateTime.now();
    if (_lastGpsSendTime != null && now.difference(_lastGpsSendTime!).inSeconds < 5) {
      return; // Throttle to 5 seconds
    }
    _lastGpsSendTime = now;

    final auth = _ref.read(authProvider);
    final userId = auth.userId ?? 65;
    final token = auth.token;

    try {
      await _dio.post(
        '/api/DriverApp/UpdateGPS',
        data: {
          'userId': userId,
          'latitude': position.latitude,
          'longtitude': position.longitude, // Swashbuckle longtitude spelling match
          'heading': position.heading,
          'speed': position.speed,
        },
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
    } catch (e) {
      // Ignore background GPS post errors to prevent crashing
    }
  }

  @override
  void dispose() {
    _stopLocationTracking();
    super.dispose();
  }
}

final shiftProvider = StateNotifierProvider<ShiftNotifier, ShiftState>((ref) {
  return ShiftNotifier(ref);
});
