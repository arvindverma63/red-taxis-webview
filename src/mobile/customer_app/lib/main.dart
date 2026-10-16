import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/logging/remote_logger.dart';
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

      // Initialise notifications AFTER the first frame so the iOS permission
      // prompt appears over the running app, not over a blank screen, and never
      // blocks start-up.
      unawaited(_initNotifications());
    },
  );
}

/// Sets up local + push notifications.
///
/// The iOS permission prompt is requested FIRST and on its own, so a Firebase
/// problem can never swallow it; push registration (Firebase) comes afterwards.
Future<void> _initNotifications() async {
  try {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    final ios = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final before = await ios.checkPermissions();
      RemoteLogger.info(
        'Permission',
        'Notification permission before prompt: alert=${before?.isAlertEnabled} sound=${before?.isSoundEnabled} badge=${before?.isBadgeEnabled}',
      );
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      RemoteLogger.info(
        'Permission',
        'Notification prompt result: granted=$granted',
      );
    }
  } catch (e) {
    RemoteLogger.error('Permission', 'Notification permission error: $e');
  }

  try {
    await CustomerNotificationService.initialize();
  } catch (e) {
    RemoteLogger.error('Permission', 'Push (Firebase) init error: $e');
  }
}
