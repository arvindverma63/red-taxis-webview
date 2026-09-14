import 'package:freezed_annotation/freezed_annotation.dart';

part 'payment_card.freezed.dart';
part 'payment_card.g.dart';

/// A customer-saved payment method. Cards are tokenised by Revolut (B9) — the
/// app never holds a raw PAN, only the brand, last four digits and a label.
@freezed
abstract class PaymentCard with _$PaymentCard {
  const factory PaymentCard({
    required String id,

    /// Card brand or wallet: `visa`, `mastercard`, `applePay`.
    required String brand,

    /// Last four digits (empty for wallet methods such as Apple Pay).
    @Default('') String last4,

    /// Human label shown in the list (e.g. "Personal Visa").
    required String label,

    /// Whether this is the default method pre-selected at checkout.
    @Default(false) bool isDefault,
  }) = _PaymentCard;

  factory PaymentCard.fromJson(Map<String, dynamic> json) =>
      _$PaymentCardFromJson(json);
}
