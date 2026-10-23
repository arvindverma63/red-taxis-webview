import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../firebase_options.dart';
import '../logging/remote_logger.dart';

/// Top-level background message handler executed when app is in background or terminated.
@pragma('vm:entry-point')
Future<void> customerFirebaseBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("[FCM Background] Firebase.initializeApp error: $e");
  }

  try {
    final notification = message.notification;

    // On iOS the OS already displays a push that carries a `notification`
    // block, so showing a local copy would just duplicate it.
    if (defaultTargetPlatform == TargetPlatform.iOS && notification != null) {
      return;
    }

    final title =
        notification?.title ?? message.data['title'] ?? '🚕 First Taxis';
    final body =
        notification?.body ??
        message.data['body'] ??
        message.data['message'] ??
        'Ride update received';

    // This runs in its own isolate: the plugin must be initialised here before
    // it can show anything, otherwise `show` throws.
    final localPlugin = FlutterLocalNotificationsPlugin();
    await localPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    const androidDetails = AndroidNotificationDetails(
      CustomerNotificationService.channelId,
      CustomerNotificationService.channelName,
      channelDescription: CustomerNotificationService.channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await localPlugin.show(
      message.messageId?.hashCode ?? message.hashCode,
      title.toString(),
      body.toString(),
      details,
      payload: _safeJson(message.data),
    );
  } catch (e) {
    debugPrint('[FCM Background] handler error (ignored): $e');
  }
}

/// JSON-encodes push data without ever throwing.
String _safeJson(Object? data) {
  try {
    return jsonEncode(data);
  } catch (_) {
    return '{}';
  }
}

class CustomerNotificationService {
  static const String channelId = 'first_taxis_alerts_channel';
  static const String channelName = 'Ride Alerts & Updates';
  static const String channelDesc =
      'Notifications for passenger ride status, driver arrival, and dispatch updates.';

  static final FlutterLocalNotificationsPlugin localPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel alertsChannel =
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  /// Initializes Firebase Core, Messaging listeners, and Android/iOS channels.
  static Future<void> initialize({
    void Function(String? payload)? onNotificationTapped,
  }) async {
    try {
      // 1. Initialize Firebase
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // 2. Set background message handler
      FirebaseMessaging.onBackgroundMessage(customerFirebaseBackgroundHandler);

      // 3. Register high-importance Android channel
      final androidPlatform = localPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlatform != null) {
        await androidPlatform.createNotificationChannel(alertsChannel);
      }

      // 4. Request user notification permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
        '[FCM] Notification authorization: ${settings.authorizationStatus}',
      );
      RemoteLogger.info('Permission',
          'FCM notification authorization: ${settings.authorizationStatus.name}');

      // 5. Configure foreground presentation options
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 6. Listen for incoming foreground push notifications
      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
          try {
            debugPrint(
              '[FCM Foreground] Received: ${message.messageId} | ${message.notification?.title}',
            );
            final notification = message.notification;

            // iOS already shows the foreground banner itself (see the
            // presentation options above); a local copy would duplicate it.
            if (defaultTargetPlatform == TargetPlatform.iOS &&
                notification != null) {
              return;
            }

            final title =
                notification?.title ??
                message.data['title'] ??
                '🚕 First Taxis';
            final body =
                notification?.body ??
                message.data['body'] ??
                message.data['message'] ??
                'Ride update received';

            await localPlugin.show(
              message.messageId?.hashCode ?? message.hashCode,
              title.toString(),
              body.toString(),
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  channelId,
                  channelName,
                  channelDescription: channelDesc,
                  importance: Importance.high,
                  priority: Priority.high,
                  playSound: true,
                  enableVibration: true,
                ),
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              payload: _safeJson(message.data),
            );
          } catch (e) {
            debugPrint('[FCM Foreground] handler error (ignored): $e');
          }
        },
        onError: (Object e) {
          debugPrint('[FCM Foreground] stream error (ignored): $e');
        },
      );

      // 7. Handle notification taps (app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        try {
          debugPrint('[FCM] Notification opened app: ${message.data}');
          if (onNotificationTapped != null) {
            onNotificationTapped(_safeJson(message.data));
          }
        } catch (e) {
          debugPrint('[FCM] opened-app handler error (ignored): $e');
        }
      });

      // 8. Retrieve initial token & listen for token refresh
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Customer device token: $token');
        await saveTokenLocally(token);
      }

      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[FCM] Customer token refreshed: $newToken');
        await saveTokenLocally(newToken);
      });
    } catch (e) {
      debugPrint('[FCM] CustomerNotificationService initialization notice: $e');
      RemoteLogger.error('Permission', 'FCM initialization failed: $e');
    }
  }

  /// Saves the active device token to secure storage.
  static Future<void> saveTokenLocally(String token) async {
    try {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'customer_fcm_token', value: token);
    } catch (_) {}
  }

  /// Sends the customer FCM token to the server whenever authenticated.
  static Future<void> syncTokenToServer(Dio dio, String? authToken) async {
    try {
      const storage = FlutterSecureStorage();
      final fcmToken = await storage.read(key: 'customer_fcm_token');
      if (fcmToken == null || fcmToken.isEmpty) return;

      final platformStr = defaultTargetPlatform == TargetPlatform.iOS
          ? 'iOS'
          : 'Android';
      final payload = {
        'fcm': fcmToken,
        'token': fcmToken,
        'deviceToken': fcmToken,
        'platform': platformStr,
      };

      final headers = <String, dynamic>{
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

      try {
        await dio.post(
          '/api/UserProfile/UpdateFCM',
          data: payload,
          options: Options(headers: headers),
        );
        debugPrint('[FCM] UserProfile/UpdateFCM synchronized successfully.');
      } catch (_) {
        // Fallback to DriverApp/UpdateFCM endpoint
        try {
          await dio.post(
            '/api/DriverApp/UpdateFCM',
            data: payload,
            options: Options(headers: headers),
          );
          debugPrint('[FCM] DriverApp/UpdateFCM synchronized successfully.');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[FCM] syncTokenToServer notice: $e');
    }
  }
}
