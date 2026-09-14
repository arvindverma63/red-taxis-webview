import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import 'booking_detail_screen.dart';

/// Activity feature routes assembled by the app router.
///
/// Only the PUSHED booking-detail route lives here. The Activity tab root
/// ([ActivityScreen]) is wired directly into the main shell's tab list, so it
/// is intentionally NOT listed here.
final List<RouteBase> activityRoutes = [
  GoRoute(
    path: '${Routes.bookingDetail}/:bookingId',
    builder: (context, state) => BookingDetailScreen(
      bookingId: state.pathParameters['bookingId']!,
    ),
  ),
];
