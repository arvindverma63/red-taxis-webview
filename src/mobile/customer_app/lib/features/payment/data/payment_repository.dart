import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/payment.dart';

/// Talks to the booking pre-pay endpoints (B9 create / B10 status / B9 refund).
///
/// The backend routes are not built yet — every method is wired against the
/// real path it will call, but currently returns a deterministic MOCK so the
/// booking flow can integrate end-to-end now. Each mock is tagged with a
/// `TODO(B9/B10)` and the exact request shape, so swapping to live is a
/// one-method change with no caller impact.
class PaymentRepository {
  PaymentRepository(this._dio);

  // ignore: unused_field — retained for the live B9/B10 calls (currently mocked)
  final Dio _dio;

  /// Creates a Revolut pre-pay order for the booking.
  ///
  /// Live: `POST /api/v2/bookings/{ref}/payment` with `{ amount }`, returns a
  /// [PaymentIntent] (orderId + optional checkoutUrl + status).
  Future<PaymentIntent> createOrder({
    required String bookingRef,
    required double amount,
  }) async {
    // TODO(B9): backend pending — replace the mock below with the real call:
    //
    //   final res = await _dio.post(
    //     '/api/v2/bookings/$bookingRef/payment',
    //     data: {'amount': amount},
    //   );
    //   return unwrapV2(res.data, (d) =>
    //       PaymentIntent.fromJson(d as Map<String, dynamic>));
    //
    // MOCK: pretend the order was created and is awaiting checkout.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return PaymentIntent(
      orderId: _mockOrderId(bookingRef),
      checkoutUrl: null, // Revolut hosted-sheet URL wiring pending.
      status: PaymentStatus.pending,
    );
  }

  /// Polls the order's payment state for the booking.
  ///
  /// Live: `GET /api/v2/bookings/{ref}/payment-status`, returns the latest
  /// [PaymentIntent].
  Future<PaymentIntent> pollStatus(String bookingRef) async {
    // TODO(B10): backend pending — replace with:
    //
    //   final res =
    //       await _dio.get('/api/v2/bookings/$bookingRef/payment-status');
    //   return unwrapV2(res.data, (d) =>
    //       PaymentIntent.fromJson(d as Map<String, dynamic>));
    //
    // MOCK: simulate the gateway settling shortly after checkout.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return PaymentIntent(
      orderId: _mockOrderId(bookingRef),
      checkoutUrl: null,
      status: PaymentStatus.completed,
    );
  }

  /// Refunds a pre-paid booking — called when the operator rejects it.
  ///
  /// Live: `POST /api/v2/bookings/{ref}/payment/refund` (B9 closes the loop via
  /// `RevolutService.RefundOrder`).
  Future<void> refund(String bookingRef) async {
    // TODO(B9): backend pending — replace with:
    //
    //   await _dio.post('/api/v2/bookings/$bookingRef/payment/refund');
    //
    // MOCK: no-op.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return;
  }

  /// Stable mock order id derived from the booking ref so create + poll agree.
  String _mockOrderId(String bookingRef) => 'mock_order_$bookingRef';
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(dioProvider));
});
