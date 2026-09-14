import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/theme/theme_controller.dart';

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
