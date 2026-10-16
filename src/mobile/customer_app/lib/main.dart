import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/notifications/customer_notification_service.dart';
import 'core/theme/theme_controller.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() {
  // Bootstrap through SentryFlutter.init. When AppConfig.sentryDsn is empty
  // (the default — local/dev with no `--dart-define=SENTRY_DSN=...`) the SDK is
  // a complete no-op: the empty DSN disables Sentry cleanly, nothing is sent,
  // and the app boots and runs normally. SentryFlutter.init installs
  // FlutterError.onError and PlatformDispatcher.onError for us, so uncaught
  // errors are captured automatically once a DSN is supplied.
  SentryFlutter.init(
    (options) {
      options.dsn = AppConfig.sentryDsn;
      options.environment = AppConfig.environment;
      // Light performance-trace sampling — cheap signal without flooding the
      // (free) quota. Irrelevant while the DSN is empty (Sentry inert).
      options.tracesSampleRate = 0.2;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();

      // Global safety net: an uncaught error anywhere (a push handler, a
      // real-time event, a stream, a build) is logged and swallowed instead of
      // tearing the app down. Sentry's own handlers are chained when active.
      final previousFlutterOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('[FlutterError] ${details.exceptionAsString()}');
        previousFlutterOnError?.call(details);
      };
      final previousPlatformOnError = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        debugPrint('[Uncaught] $error');
        previousPlatformOnError?.call(error, stack);
        return true; // handled — do not crash.
      };
      // A widget that fails to build shows a small message, not a blank/red screen.
      ErrorWidget.builder = (FlutterErrorDetails details) => const Material(
        color: Colors.transparent,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong. Please go back and try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );

      // Initialize notifications and request permissions on iOS and Android
      try {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const DarwinInitializationSettings initializationSettingsDarwin =
            DarwinInitializationSettings(
              requestAlertPermission: true,
              requestBadgePermission: true,
              requestSoundPermission: true,
            );
        const InitializationSettings initializationSettings =
            InitializationSettings(
              android: initializationSettingsAndroid,
              iOS: initializationSettingsDarwin,
            );

        await flutterLocalNotificationsPlugin.initialize(
          initializationSettings,
        );

        // Explicitly request iOS notification authorization
        final iosPlugin = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (iosPlugin != null) {
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          debugPrint(
            "iOS customer app notification permission granted: $granted",
          );
        }

        // Request system notification permission via permission_handler (Android 13+ & iOS)
        await Permission.notification.request();

        // Initialize Firebase Cloud Messaging (FCM) & register background handlers
        await CustomerNotificationService.initialize();
      } catch (e) {
        debugPrint('Customer app notification init error: $e');
      }

      // Load the saved theme preference before the first frame so the app
      // paints straight into the chosen mode (dark by default) — no flash.
      const storage = FlutterSecureStorage(aOptions: AndroidOptions());
      final initialThemeMode = await loadInitialThemeMode(storage);
      runApp(
        ProviderScope(
          overrides: [
            initialThemeModeProvider.overrideWithValue(initialThemeMode),
          ],
          child: const CustomerApp(),
        ),
      );
    },
  );
}
