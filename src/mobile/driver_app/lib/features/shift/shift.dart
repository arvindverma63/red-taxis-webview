import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:driver_app/core/location/location.dart';
import 'package:driver_app/features/auth/auth.dart';

enum ShiftStatus { offline, online }

class ShiftState {
  final ShiftStatus status;
  final DateTime? startTime;

  const ShiftState({
    required this.status,
    this.startTime,
  });

  ShiftState copyWith({
    ShiftStatus? status,
    DateTime? startTime,
  }) {
    return ShiftState(
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
    );
  }
}

class ShiftNotifier extends StateNotifier<ShiftState> {
  final Ref _ref;
  StreamSubscription<Position>? _locationSubscription;
  final _locationService = LocationService();
  DateTime? _lastGpsSendTime;

  final _dio = Dio(BaseOptions(
    baseUrl: 'https://staging-api.redtaxi.co.uk',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  ShiftNotifier(this._ref) : super(const ShiftState(status: ShiftStatus.offline));

  Future<void> goOnline() async {
    final auth = _ref.read(authProvider);
    final userId = auth.userId ?? 65;
    final token = auth.token;

    try {
      await _dio.get(
        '/api/DriverApp/DriverShift',
        queryParameters: {
          'userid': userId,
          'status': 1001,
        },
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
    } catch (e) {
      // Proceed locally even if API call fails
    }

    // Start location tracking
    final hasPermission = await _locationService.checkPermissions();
    if (hasPermission) {
      _locationSubscription?.cancel();
      _locationSubscription = _locationService.getLocationStream().listen((position) {
        _sendGpsUpdate(position);
      });
    }

    state = ShiftState(
      status: ShiftStatus.online,
      startTime: DateTime.now(),
    );
  }

  Future<void> goOffline() async {
    final auth = _ref.read(authProvider);
    final userId = auth.userId ?? 65;
    final token = auth.token;

    try {
      await _dio.get(
        '/api/DriverApp/DriverShift',
        queryParameters: {
          'userid': userId,
          'status': 1000,
        },
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
    } catch (e) {
      // Proceed locally
    }

    _locationSubscription?.cancel();
    _locationSubscription = null;

    state = const ShiftState(status: ShiftStatus.offline);
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
    _locationSubscription?.cancel();
    super.dispose();
  }
}

final shiftProvider = StateNotifierProvider<ShiftNotifier, ShiftState>((ref) {
  return ShiftNotifier(ref);
});
