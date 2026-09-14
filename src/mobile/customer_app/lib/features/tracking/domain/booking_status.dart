import '../../../core/widgets/status_chip.dart';

/// The lifecycle of a booking as the customer experiences it on the tracking
/// screen. Mirrors the Pusher status events in the PRD §8
/// (`booking.confirmed`, `booking.allocated`, ...). Order matters: the
/// [timelineOrder] list drives the timeline UI.
enum BookingStatus {
  /// Request submitted, awaiting operator confirmation.
  requested,

  /// Operator accepted the request — it is now a live dispatch job.
  confirmed,

  /// A driver has been assigned to the booking.
  allocated,

  /// The assigned driver is en route to the pickup.
  arriving,

  /// The driver has reached the pickup point.
  arrived,

  /// The passenger is on board and the trip is underway.
  inProgress,

  /// Trip finished.
  completed,

  /// Booking cancelled (by customer or operator).
  cancelled,
}

/// Display + semantic helpers for [BookingStatus]. Kept as an extension so the
/// enum itself stays a plain value the data layer can map cheaply.
extension BookingStatusX on BookingStatus {
  /// Customer-facing label for chips and headings.
  String get label => switch (this) {
        BookingStatus.requested => 'Requested',
        BookingStatus.confirmed => 'Confirmed',
        BookingStatus.allocated => 'Driver assigned',
        BookingStatus.arriving => 'Driver on the way',
        BookingStatus.arrived => 'Driver arrived',
        BookingStatus.inProgress => 'On your trip',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
      };

  /// Shorter label used inside the compact timeline rows.
  String get timelineLabel => switch (this) {
        BookingStatus.requested => 'Requested',
        BookingStatus.confirmed => 'Confirmed',
        BookingStatus.allocated => 'Driver assigned',
        BookingStatus.arriving => 'On the way',
        BookingStatus.arrived => 'Arrived',
        BookingStatus.inProgress => 'In progress',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
      };

  /// Semantic colour bucket for [StatusChip] / coloured dots.
  StatusKind get statusKind => switch (this) {
        BookingStatus.requested => StatusKind.pending,
        BookingStatus.confirmed => StatusKind.active,
        BookingStatus.allocated => StatusKind.active,
        BookingStatus.arriving => StatusKind.active,
        BookingStatus.arrived => StatusKind.active,
        BookingStatus.inProgress => StatusKind.active,
        BookingStatus.completed => StatusKind.success,
        BookingStatus.cancelled => StatusKind.danger,
      };

  /// True once a driver exists for the booking (drives map marker + driver
  /// card visibility).
  bool get hasDriver => index >= BookingStatus.allocated.index &&
      this != BookingStatus.cancelled &&
      this != BookingStatus.completed;

  /// True for the terminal success state.
  bool get isComplete => this == BookingStatus.completed;

  /// True for the terminal cancelled state.
  bool get isCancelled => this == BookingStatus.cancelled;

  /// Position of this status within the happy-path timeline, or `-1` for
  /// statuses that are not part of it (i.e. [BookingStatus.cancelled]).
  int get timelineIndex => timelineOrder.indexOf(this);

  /// The ordered happy-path statuses shown in the tracking timeline.
  /// Excludes [BookingStatus.cancelled] (rendered as a separate state).
  static const List<BookingStatus> timelineOrder = [
    BookingStatus.requested,
    BookingStatus.confirmed,
    BookingStatus.allocated,
    BookingStatus.arriving,
    BookingStatus.arrived,
    BookingStatus.inProgress,
    BookingStatus.completed,
  ];
}
