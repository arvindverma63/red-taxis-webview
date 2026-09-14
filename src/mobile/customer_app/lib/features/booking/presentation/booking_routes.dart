import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import 'address_search_screen.dart';
import 'booking_confirm_screen.dart';
import 'booking_review_screen.dart';
import 'payment_method_screen.dart';
import 'pick_on_map_screen.dart';

/// Feature-local path for the "Select from map" pickup/dropoff picker
/// (GoRide frame 30439:395). Kept here (not in `core`'s shared `Routes`) so the
/// booking feature owns its additive route without touching core/.
const String kPickOnMapPath = '/booking/pick-on-map';

/// Booking flow routes that are PUSHED on top of the tab shell. The Home tab
/// root (`HomeScreen`) is wired by the shell, NOT here.
///
/// - addressSearch: `extra` is `'pickup'` or `'dropoff'` (defaults to dropoff).
/// - pickOnMap: `extra` is `'pickup'` or `'dropoff'` (defaults to dropoff).
/// - bookingConfirm: `extra` is the request id String.
final List<RouteBase> bookingRoutes = [
  GoRoute(
    path: Routes.addressSearch,
    name: 'addressSearch',
    builder: (context, state) {
      final mode = state.extra == 'pickup'
          ? AddressMode.pickup
          : AddressMode.dropoff;
      return AddressSearchScreen(mode: mode);
    },
  ),
  GoRoute(
    path: kPickOnMapPath,
    name: 'pickOnMap',
    builder: (context, state) {
      final mode = state.extra == 'pickup'
          ? AddressMode.pickup
          : AddressMode.dropoff;
      return PickOnMapScreen(mode: mode);
    },
  ),
  GoRoute(
    path: Routes.bookingReview,
    name: 'bookingReview',
    builder: (context, state) => const BookingReviewScreen(),
  ),
  GoRoute(
    path: Routes.paymentMethod,
    name: 'paymentMethod',
    builder: (context, state) => const PaymentMethodScreen(),
  ),
  GoRoute(
    path: Routes.bookingConfirm,
    name: 'bookingConfirm',
    builder: (context, state) {
      final requestId = state.extra is String ? state.extra as String : '';
      return BookingConfirmScreen(requestId: requestId);
    },
  ),
];
