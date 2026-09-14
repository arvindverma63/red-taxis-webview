import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/constants.dart';
import '../../features/auth/application/auth_notifier.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/tenant_qr_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/shell/customer_main_shell.dart';
import '../../features/webview/presentation/customer_webview_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorBookKey = GlobalKey<NavigatorState>(debugLabel: 'book');
final _shellNavigatorRidesKey = GlobalKey<NavigatorState>(debugLabel: 'rides');
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/auth/login' ||
          state.matchedLocation == '/auth/register' ||
          state.matchedLocation == '/auth/qr-scan';

      if (!isAuth && !isLoggingIn) {
        return '/auth/login';
      }
      if (isAuth && isLoggingIn) {
        return '/home';
      }
      return null;
    },
    routes: [
      // Native Auth & Onboarding Routes
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/qr-scan',
        builder: (context, state) => const TenantQrScreen(),
      ),

      // Native Settings Route
      GoRoute(
        path: '/settings',
        builder: (context, state) => const CustomerSettingsScreen(),
      ),

      // Webview Full-Screen Overlays (Active Tracking & Saved Places)
      GoRoute(
        path: '/rides/active',
        builder: (context, state) => const CustomerWebviewScreen(
          subRoute: AppConfig.webviewActiveRideRoute,
          title: 'Live Tracking',
          showBackButton: true,
        ),
      ),
      GoRoute(
        path: '/saved-places',
        builder: (context, state) => const CustomerWebviewScreen(
          subRoute: AppConfig.webviewSavedPlacesRoute,
          title: 'Saved Places',
          showBackButton: true,
        ),
      ),

      // Hybrid Webview Navigation Shell
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return CustomerMainShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Book / Home (Webview)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorBookKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const CustomerWebviewScreen(
                  subRoute: AppConfig.webviewBookRoute,
                  title: 'Book a Taxi',
                ),
              ),
            ],
          ),
          // Branch 1: Activity / Rides (Webview)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorRidesKey,
            routes: [
              GoRoute(
                path: '/rides/history',
                builder: (context, state) => const CustomerWebviewScreen(
                  subRoute: AppConfig.webviewActivityRoute,
                  title: 'My Rides',
                ),
              ),
            ],
          ),
          // Branch 2: Account / Profile (Webview)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorProfileKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const CustomerWebviewScreen(
                  subRoute: AppConfig.webviewProfileRoute,
                  title: 'My Account',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
