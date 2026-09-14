import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

/// Root widget. Wires the light + dark themes and the user's persisted theme
/// choice (defaults to dark; switchable in Settings → Appearance) and the router.
class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = AppConfig.fromEnvironment();
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: config.brandName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
