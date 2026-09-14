import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment.freezed.dart';
part 'payment.g.dart';

/// How a booking is paid for.
///
/// `cash` and `account` need no in-app checkout (cash is collected by the
/// driver, account bookings are invoiced). `card` and `applePay` are pre-paid
/// via Revolut at booking time — the only kinds that drive the checkout flow.
enum PaymentMethodKind {
  cash,
  card,
  applePay,
  account;

  /// Human-readable label for selection lists and the checkout header.
  String get label => switch (this) {
        PaymentMethodKind.cash => 'Cash',
        PaymentMethodKind.card => 'Card',
        PaymentMethodKind.applePay => 'Apple Pay',
        PaymentMethodKind.account => 'Account',
      };

  /// Icon for this method. Kept in the domain as the single source of truth so
  /// every surface (method picker, checkout, receipt) renders the same glyph.
  IconData get icon => switch (this) {
        PaymentMethodKind.cash => Icons.payments_outlined,
        PaymentMethodKind.card => Icons.credit_card,
        PaymentMethodKind.applePay => Icons.apple,
        PaymentMethodKind.account => Icons.business_outlined,
      };

  /// True when selecting this method requires the pre-pay checkout sheet.
  /// Cash and account bookings skip payment entirely.
  bool get requiresCheckout =>
      this == PaymentMethodKind.card || this == PaymentMethodKind.applePay;
}

/// Lifecycle status of a Revolut pre-pay order.
abstract final class PaymentStatus {
  static const pending = 'pending';
  static const completed = 'completed';
  static const failed = 'failed';
}

/// A pre-pay order created against a booking.
///
/// Mirrors the B9 (`POST /api/v2/bookings/{ref}/payment`) response: an
/// [orderId] to reconcile against, an optional [checkoutUrl] for the Revolut
/// hosted sheet, and a [status] (`pending` | `completed` | `failed`).
@freezed
abstract class PaymentIntent with _$PaymentIntent {
  const factory PaymentIntent({
    required String orderId,
    String? checkoutUrl,
    required String status,
  }) = _PaymentIntent;

  const PaymentIntent._();

  factory PaymentIntent.fromJson(Map<String, dynamic> json) =>
      _$PaymentIntentFromJson(json);

  bool get isCompleted => status == PaymentStatus.completed;
  bool get isFailed => status == PaymentStatus.failed;
  bool get isPending => status == PaymentStatus.pending;
}
