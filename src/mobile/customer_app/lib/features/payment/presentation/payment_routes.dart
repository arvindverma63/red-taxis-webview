import 'package:go_router/go_router.dart';

import '../domain/payment.dart';
import 'payment_processing_screen.dart';

// Re-export the screen + domain so the booking flow can depend on a single
// `payment_routes.dart` import for both the pushed route and a direct push.
export '../domain/payment.dart' show PaymentMethodKind, PaymentIntent;
export 'payment_processing_screen.dart' show PaymentProcessingScreen;

/// Path for the standalone pre-pay checkout route.
const String paymentCheckoutPath = '/payment/checkout';

/// Route name for `context.pushNamed`.
const String paymentCheckoutName = 'payment-checkout';

/// Arguments for the checkout route, passed as `GoRouterState.extra`.
///
/// The booking flow builds this from the active booking + quote + chosen
/// method, then `context.push(paymentCheckoutPath, extra: args)`.
class PaymentCheckoutArgs {
  const PaymentCheckoutArgs({
    required this.bookingRef,
    required this.amount,
    this.method = PaymentMethodKind.card,
  });

  final String bookingRef;
  final double amount;
  final PaymentMethodKind method;
}

/// Feature routes. Spread into the app router's `routes:` list. Self-contained
/// so adding payment to navigation is a one-line `...paymentRoutes`.
///
/// The route returns `true` (via `Navigator.pop(true)`) on a successful
/// pre-pay, which the awaiting booking step uses to submit the request.
final List<RouteBase> paymentRoutes = [
  GoRoute(
    path: paymentCheckoutPath,
    name: paymentCheckoutName,
    builder: (context, state) {
      final args = state.extra as PaymentCheckoutArgs?;
      // Defensive defaults: a misrouted push still renders a usable (if zero)
      // checkout rather than crashing.
      return PaymentProcessingScreen(
        bookingRef: args?.bookingRef ?? 'unknown',
        amount: args?.amount ?? 0,
        method: args?.method ?? PaymentMethodKind.card,
      );
    },
  ),
];
