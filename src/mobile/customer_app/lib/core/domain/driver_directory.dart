import 'driver_fields.dart';

/// In-memory record of the assigned driver's details (phone, rating, photo,
/// vehicle colour, plate) per booking id.
///
/// The booking and tracking models only carry the fields the app has always
/// used; the repositories note every driver detail the API returns here as they
/// parse, and the booking-details and tracking screens read it back. Later
/// responses fill gaps but never erase a value that is already known.
class DriverDirectory {
  DriverDirectory._();

  static final Map<String, DriverFields> _byBooking = {};

  /// The driver details seen so far for [bookingId], if any.
  static DriverFields? of(String bookingId) => _byBooking[bookingId];

  /// Records [fields] for [bookingId], merging with what is already known.
  static void remember(String bookingId, DriverFields fields) {
    if (bookingId.isEmpty || !fields.hasName) return;
    final old = _byBooking[bookingId];
    _byBooking[bookingId] = old == null ? fields : old.mergedWith(fields);
  }
}
