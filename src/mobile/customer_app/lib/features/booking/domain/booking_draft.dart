import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/place.dart';
import 'quote.dart';

part 'booking_draft.freezed.dart';

/// The in-progress booking, threaded through the flow via `bookingDraftProvider`
/// and mutated by `BookingDraftController`. Not serialised — it lives in memory
/// for the duration of one booking and is rebuilt into the request payload at
/// confirmation time.
///
/// [scheduledFor] null means ASAP ("Now"). [paymentMethod] is one of
/// `'cash' | 'card' | 'applePay' | 'account'`.
@freezed
abstract class BookingDraft with _$BookingDraft {
  const BookingDraft._();

  const factory BookingDraft({
    Place? pickup,
    Place? dropoff,
    @Default(<Place>[]) List<Place> vias,
    @Default('saloon') String vehicleId,
    @Default(1) int passengers,
    DateTime? scheduledFor,
    @Default('cash') String paymentMethod,
    Quote? quote,
  }) = _BookingDraft;

  /// True once both ends of the journey are set — gates the review/quote step.
  bool get hasRoute => pickup != null && dropoff != null;

  /// True when the ride is "Now" (no scheduled time).
  bool get isAsap => scheduledFor == null;
}
