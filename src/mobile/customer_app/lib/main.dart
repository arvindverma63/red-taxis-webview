import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
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

        // Explicitly request permissions on iOS/macOS via Darwin plugin
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                DarwinFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );

        // Request system notification permission via permission_handler (Android 13+ & iOS)
        await Permission.notification.request();
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
