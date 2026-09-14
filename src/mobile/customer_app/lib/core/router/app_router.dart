import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../network/dio_client.dart';
import '../session/session_controller.dart';
import 'main_shell.dart';
import 'route_paths.dart';

// Feature route bundles + tab-root screens.
import '../../features/auth/auth_routes.dart';
import '../../features/booking/presentation/booking_routes.dart';
import '../../features/booking/presentation/home_screen.dart';
import '../../features/tracking/tracking_routes.dart';
import '../../features/activity/presentation/activity_routes.dart';
import '../../features/activity/presentation/activity_screen.dart';
import '../../features/payment/presentation/payment_routes.dart';
import '../../features/profile/presentation/profile_routes.dart';
import '../../features/profile/presentation/profile_screen.dart';

/// Routes reachable without a session. Everything else redirects to sign-in.
const _publicRoutes = <String>{
  Routes.splash,
  Routes.onboarding,
  Routes.signIn,
  Routes.signUp,
  Routes.forgotPassword,
  Routes.resetPassword,
  Routes.verifyEmail,
};

final _homeKey = GlobalKey<NavigatorState>();
final _activityKey = GlobalKey<NavigatorState>();
final _profileKey = GlobalKey<NavigatorState>();

/// The app router. Rebuilt-free: auth changes drive redirects via the
/// [_RouterRefresh] listenable rather than recreating the router.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(sessionProvider) != null;
      final expired = ref.read(sessionExpiredProvider);
      final loc = state.matchedLocation;
      final isPublic =
          _publicRoutes.contains(loc) || loc == Routes.splash;

      // Forced logout (refresh failed) → sign-in.
      if (expired && loc != Routes.signIn) return Routes.signIn;

      // Gate protected routes.
      if (!loggedIn && !isPublic) return Routes.signIn;

      // Bounce signed-in users away from the auth entry screens.
      if (loggedIn &&
          (loc == Routes.signIn ||
              loc == Routes.signUp ||
              loc == Routes.onboarding)) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      ...authRoutes,
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeKey,
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _activityKey,
            routes: [
              GoRoute(
                path: Routes.activity,
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileKey,
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      ...bookingRoutes,
      ...trackingRoutes,
      ...activityRoutes,
      ...profileRoutes,
      ...paymentRoutes,
    ],
    errorBuilder: (context, state) => const _RouteError(),
  );
});

/// Notifies go_router to re-run [redirect] when the session or expiry flips.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _subs = [
      ref.listen(sessionProvider, (_, __) => notifyListeners()),
      ref.listen(sessionExpiredProvider, (_, __) => notifyListeners()),
    ];
  }
  late final List<ProviderSubscription> _subs;

  @override
  void dispose() {
    for (final s in _subs) {
      s.close();
    }
    super.dispose();
  }
}

class _RouteError extends StatelessWidget {
  const _RouteError();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Page not found')));
}
