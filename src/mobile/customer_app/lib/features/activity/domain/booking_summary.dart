import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/place.dart';
import '../../../core/widgets/status_chip.dart';

part 'booking_summary.freezed.dart';
part 'booking_summary.g.dart';

/// A single row in the customer's Activity list and the source for the booking
/// detail screen. Mirrors the (pending, B3) `GET /api/v2/customers/me/bookings`
/// item shape: pickup/dropoff places, schedule, status, price and vehicle.
///
/// [status] is kept as a raw string matching the backend `Status` field and the
/// tracking feature's `BookingStatus` enum *names*
/// (`requested`/`confirmed`/`allocated`/`arriving`/`arrived`/`inProgress`/
/// `completed`/`cancelled`) so the data layer can map cheaply without this
/// feature importing the tracking enum.
@freezed
abstract class BookingSummary with _$BookingSummary {
  const BookingSummary._();

  const factory BookingSummary({
    required String id,
    required Place pickup,
    required Place dropoff,
    required DateTime scheduledFor,
    required String status,
    required double price,
    required String vehicleName,
    required int passengers,
    required String paymentMethod,
  }) = _BookingSummary;

  factory BookingSummary.fromJson(Map<String, dynamic> json) =>
      _$BookingSummaryFromJson(json);

  /// The set of statuses that are terminal — the booking is no longer live.
  static const _terminal = {'completed', 'cancelled'};

  /// Normalised status (defensive against casing/whitespace from the API).
  String get _statusKey => status.trim();

  /// True while the booking is still live (not completed or cancelled). Drives
  /// the Current vs History split and the "Track" / amend / cancel affordances.
  bool get isActive => !_terminal.contains(_statusKey);

  /// True for the terminal cancelled state.
  bool get isCancelled => _statusKey == 'cancelled';

  /// True for the terminal completed state.
  bool get isCompleted => _statusKey == 'completed';

  /// Statuses where a driver is engaged and the trip is effectively live —
  /// drives the GoRide "Ongoing" tab vs the awaiting-allocation "Scheduled" tab.
  static const _engaged = {'allocated', 'arriving', 'arrived', 'inProgress'};

  /// True once a driver has been assigned / is en route / the trip is underway.
  /// (`requested`/`confirmed` bookings are active but not yet engaged.)
  bool get isDriverEngaged => _engaged.contains(_statusKey);

  /// How far into the future a booking's [scheduledFor] must be before it counts
  /// as a genuinely "book ahead" scheduled trip rather than an ASAP / "Now" ride.
  /// ASAP bookings get a near-now pickup time stamped by the operator at
  /// creation, so a small window absorbs that plus any client/clock skew.
  static const _scheduledLeadTime = Duration(minutes: 10);

  /// True when this is an ASAP / "Now" ride — its pickup is now (or in the past),
  /// not booked meaningfully ahead. [BookingSummary] always carries a concrete
  /// [scheduledFor] (unlike the in-flight `BookingDraft`), so "Now" is inferred
  /// from the pickup time sitting within [_scheduledLeadTime] of now.
  bool get isAsap =>
      scheduledFor.isBefore(DateTime.now().add(_scheduledLeadTime));

  /// True when this is a genuinely future-dated, booked-ahead trip — the only
  /// case the "Scheduled" tab and the "Your Scheduled Ride" header should claim.
  bool get isScheduled => !isAsap;

  /// True while the trip belongs in the active, in-flight "Ongoing" bucket: a
  /// driver is engaged, or it's a live ASAP request still awaiting allocation.
  /// A just-requested "Now" booking lands here (not under "Scheduled") so the
  /// customer sees it where they expect immediately after booking.
  bool get isOngoing => isActive && (isDriverEngaged || isAsap);

  /// True while the trip belongs in the "Scheduled" bucket: active, not yet
  /// driver-engaged, and booked for a genuinely future time.
  bool get isAwaitingScheduled =>
      isActive && !isDriverEngaged && isScheduled;

  /// Customer-facing label for the status chip and headings.
  String get statusLabel => switch (_statusKey) {
        'requested' => 'Requested',
        'confirmed' => 'Confirmed',
        'allocated' => 'Driver assigned',
        'arriving' => 'Driver on the way',
        'arrived' => 'Driver arrived',
        'inProgress' => 'On your trip',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        _ => 'Booking',
      };

  /// Semantic colour bucket for [StatusChip].
  StatusKind get statusKind => switch (_statusKey) {
        'requested' => StatusKind.pending,
        'confirmed' ||
        'allocated' ||
        'arriving' ||
        'arrived' ||
        'inProgress' =>
          StatusKind.active,
        'completed' => StatusKind.success,
        'cancelled' => StatusKind.danger,
        _ => StatusKind.neutral,
      };
}
