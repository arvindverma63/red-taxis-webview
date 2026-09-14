import 'package:go_router/go_router.dart';

import '../../core/router/route_paths.dart';
import 'presentation/tracking_screen.dart';

/// Tracking feature routes. Assembled into the app router alongside the other
/// features. The booking id is a path parameter so push-notification taps
/// (`/tracking/{bookingId}`) deep-link straight to a live trip.
final List<RouteBase> trackingRoutes = [
  GoRoute(
    path: '${Routes.tracking}/:bookingId',
    name: 'tracking',
    builder: (context, state) => TrackingScreen(
      bookingId: state.pathParameters['bookingId']!,
    ),
  ),
];
