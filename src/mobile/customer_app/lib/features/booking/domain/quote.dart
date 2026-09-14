import 'package:freezed_annotation/freezed_annotation.dart';

part 'quote.freezed.dart';
part 'quote.g.dart';

/// A fare estimate from `POST /api/v2/pricing/quote`. The API returns a driver
/// price (cash) and an account price; the customer sees whichever applies to
/// their payment method. Mileage/duration are pre-formatted by the API
/// ([mileageText]/[durationText]) with raw values kept for any local display.
@freezed
abstract class Quote with _$Quote {
  const factory Quote({
    @Default(0) double priceCash,
    @Default(0) double priceAccount,
    @Default(0) double totalMileage,
    @Default(0) int totalMinutes,
    @Default('') String mileageText,
    @Default('') String durationText,
  }) = _Quote;

  factory Quote.fromJson(Map<String, dynamic> json) => _$QuoteFromJson(json);
}
