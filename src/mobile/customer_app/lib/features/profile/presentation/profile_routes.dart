import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import 'notifications_screen.dart';
import 'payment_methods_screen.dart';
import 'saved_addresses_screen.dart';
import 'settings_screen.dart';

/// Pushed routes for the profile feature's sub-pages. The profile *tab root*
/// ([ProfileScreen]) is wired by the app shell against [Routes.profile], so it
/// is intentionally NOT listed here — only the pages pushed on top of it are.
final List<RouteBase> profileRoutes = [
  GoRoute(
    path: Routes.savedAddresses,
    name: 'savedAddresses',
    builder: (context, state) => const SavedAddressesScreen(),
  ),
  GoRoute(
    path: Routes.paymentMethods,
    name: 'paymentMethods',
    builder: (context, state) => const PaymentMethodsScreen(),
  ),
  GoRoute(
    path: Routes.settings,
    name: 'settings',
    builder: (context, state) => const SettingsScreen(),
  ),
  GoRoute(
    path: Routes.notifications,
    name: 'notifications',
    builder: (context, state) => const NotificationsScreen(),
  ),
];
