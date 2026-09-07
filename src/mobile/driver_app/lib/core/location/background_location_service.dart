import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:driver_app/core/config/constants.dart';

const String _bgNotificationChannelId = 'driver_bg_location_channel';
const int _bgNotificationId = 999;

Future<void> initializeBackgroundLocationService() async {
  if (kIsWeb) return;

  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    _bgNotificationChannelId,
    'Driver GPS Location Service',
    description: 'Maintains continuous background GPS tracking for active shifts and booking dispatches.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _bgNotificationChannelId,
      initialNotificationTitle: 'First Taxis Driver Active',
      initialNotificationContent: 'Connecting continuous background GPS tracking...',
      foregroundServiceNotificationId: _bgNotificationId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onBackgroundServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final dio = Dio(BaseOptions(
    baseUrl: 'https://staging-api.redtaxi.co.uk',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Stream position updates continuously
  StreamSubscription<Position>? positionSubscription;

  try {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) async {
        await _processAndSendLocation(position, service, storage, dio);
      },
      onError: (err) {
        debugPrint('[BackgroundService] Position stream error: $err');
      },
    );
  } catch (e) {
    debugPrint('[BackgroundService] Error setting up position stream: $e');
  }

  // Periodic heartbeat timer (every 5 seconds) to ensure GPS is transmitted even when stationary
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    try {
      final isOnline = await storage.read(key: 'shift_online');
      if (isOnline != 'true') {
        positionSubscription?.cancel();
        timer.cancel();
        service.stopSelf();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _processAndSendLocation(position, service, storage, dio);
    } catch (e) {
      debugPrint('[BackgroundService] Heartbeat GPS error: $e');
    }
  });
}

DateTime? _lastSentTime;

Future<void> _processAndSendLocation(
  Position position,
  ServiceInstance service,
  FlutterSecureStorage storage,
  Dio dio,
) async {
  final now = DateTime.now();
  if (_lastSentTime != null && now.difference(_lastSentTime!).inMilliseconds < 4000) {
    return; // Throttle to 4 seconds
  }
  _lastSentTime = now;

  try {
    final isOnline = await storage.read(key: 'shift_online');
    if (isOnline != 'true') return;

    final token = await storage.read(key: AppConfig.keyAuthToken);
    final userIdStr = await storage.read(key: AppConfig.keyAuthUserId);
    final userId = userIdStr != null ? int.tryParse(userIdStr) : 65;

    final brandingJson = await storage.read(key: AppConfig.keyTenantBranding);
    String fleetName = 'First Taxis';
    if (brandingJson != null) {
      try {
        final decoded = brandingJson;
        if (decoded.contains('Ace Taxis')) {
          fleetName = 'Ace Taxis';
        } else if (decoded.contains('Red Taxis')) {
          fleetName = 'Red Taxis';
        }
      } catch (_) {}
    }

    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: '$fleetName • Online & Tracking',
          content: 'Live GPS Active • Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)} (Speed: ${(position.speed * 2.23694).toStringAsFixed(1)} mph)',
        );
      }
    }

    await dio.post(
      '/api/DriverApp/UpdateGPS',
      data: {
        'userId': userId,
        'latitude': position.latitude,
        'longtitude': position.longitude, // Swashbuckle match
        'heading': position.heading,
        'speed': position.speed,
      },
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      ),
    );
    debugPrint('[BackgroundService] GPS Update Sent: lat=${position.latitude}, lng=${position.longitude}, speed=${position.speed}');
  } catch (e) {
    debugPrint('[BackgroundService] Failed to send GPS update: $e');
  }
}
