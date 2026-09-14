import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/place.dart';
import '../domain/booking_draft.dart';
import '../domain/quote.dart';

/// Holds the in-progress [BookingDraft] for the whole flow. Every booking
/// screen watches `bookingDraftProvider` and mutates it through these setters —
/// the draft is the single source of truth threaded from Home → confirm.
class BookingDraftController extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  void setPickup(Place place) =>
      state = state.copyWith(pickup: place, quote: null);

  void setDropoff(Place place) =>
      state = state.copyWith(dropoff: place, quote: null);

  void setVias(List<Place> vias) =>
      state = state.copyWith(vias: vias, quote: null);

  /// Selecting a different vehicle invalidates the current quote (price varies
  /// by class) so the review screen refetches.
  void setVehicle(String vehicleId) =>
      state = state.copyWith(vehicleId: vehicleId, quote: null);

  void setPassengers(int passengers) =>
      state = state.copyWith(passengers: passengers.clamp(1, 8), quote: null);

  /// [scheduledFor] null = ASAP. Changing the time invalidates the quote.
  void setSchedule(DateTime? scheduledFor) =>
      state = state.copyWith(scheduledFor: scheduledFor, quote: null);

  void setPaymentMethod(String method) =>
      state = state.copyWith(paymentMethod: method);

  void setQuote(Quote quote) => state = state.copyWith(quote: quote);

  /// Clears the draft — called after a booking is submitted or abandoned.
  void reset() => state = const BookingDraft();
}

final bookingDraftProvider =
    NotifierProvider<BookingDraftController, BookingDraft>(
  BookingDraftController.new,
);
