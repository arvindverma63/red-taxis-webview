import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/features/navigation/presentation/main_shell.dart';

void main() {
  runApp(
    const ProviderScope(
      child: DriverApp(),
    ),
  );
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainShell(),
    ),
  ],
);

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Red Taxi Driver',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Enforce light mode only as requested
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
