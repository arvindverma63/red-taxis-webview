import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme.dart';

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(tenantBrandingProvider);
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: branding.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(branding),
      darkTheme: AppTheme.darkTheme(branding),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
