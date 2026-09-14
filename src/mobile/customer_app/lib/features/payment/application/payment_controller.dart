import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/payment_repository.dart';
import '../domain/payment.dart';

/// Drives the pre-pay checkout for a single booking.
///
/// State is the resolved [PaymentIntent] (or `null` before any attempt). The
/// `AsyncValue` wrapper carries loading + error so the screen can render a
/// spinner / retry without its own flags.
///
/// [pay] runs the full simulated flow: create the order (B9), simulate the
/// card / Apple Pay sheet, then poll until the gateway settles (B10). When the
/// backend lands, only the repository changes — this orchestration stays.
class PaymentController extends AsyncNotifier<PaymentIntent?> {
  @override
  Future<PaymentIntent?> build() async => null;

  PaymentRepository get _repo => ref.read(paymentRepositoryProvider);

  /// Creates the order, simulates the checkout sheet, polls status and resolves
  /// to a completed/failed [PaymentIntent].
  ///
  /// Cash and account methods never reach here — they skip the checkout — but
  /// the guard keeps the controller honest if called with a non-card method.
  Future<PaymentIntent> pay({
    required String bookingRef,
    required double amount,
    required PaymentMethodKind method,
  }) async {
    if (!method.requiresCheckout) {
      // Non-card methods are settled outside the app; treat as immediately done.
      final intent = PaymentIntent(
        orderId: 'no_charge_$bookingRef',
        status: PaymentStatus.completed,
      );
      state = AsyncData(intent);
      return intent;
    }

    state = const AsyncLoading();
    final result = await AsyncValue.guard<PaymentIntent>(() async {
      // 1. Create the Revolut order (B9).
      final order = await _repo.createOrder(
        bookingRef: bookingRef,
        amount: amount,
      );

      // 2. Simulate the native card / Apple Pay sheet authorising the charge.
      //    Replaced by the Revolut SDK / hosted checkout when wired.
      await _simulateCheckoutSheet();

      // 3. Poll the gateway until it settles (B10).
      final settled = await _repo.pollStatus(bookingRef);

      if (settled.isFailed) {
        throw const PaymentFailure('Payment was declined. Please try again.');
      }
      return order.copyWith(status: settled.status, orderId: settled.orderId);
    });

    state = result;
    // Surface the failure to the caller (the screen swallows it for retry UI).
    return result.value ?? (throw result.error ?? const PaymentFailure());
  }

  /// Issues a refund for a pre-paid booking (operator-reject path).
  Future<void> refund(String bookingRef) => _repo.refund(bookingRef);

  /// Resets to the pre-attempt state so the screen can offer a clean retry.
  void reset() => state = const AsyncData(null);

  Future<void> _simulateCheckoutSheet() =>
      Future<void>.delayed(const Duration(milliseconds: 1200));
}

/// Raised when the simulated (or, later, real) checkout does not complete.
class PaymentFailure implements Exception {
  const PaymentFailure([this.message = 'Payment could not be completed.']);

  final String message;

  @override
  String toString() => message;
}

final paymentControllerProvider =
    AsyncNotifierProvider<PaymentController, PaymentIntent?>(
  PaymentController.new,
);
