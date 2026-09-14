import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_item.freezed.dart';
part 'notification_item.g.dart';

/// A single entry in the customer's notification inbox. Mirrors a received push
/// (booking lifecycle events). Tapping one with a [bookingId] deep-links to the
/// booking detail.
@freezed
abstract class NotificationItem with _$NotificationItem {
  const factory NotificationItem({
    required String id,
    required String title,
    required String body,

    /// When the notification was raised.
    required DateTime time,

    /// Event type: `booking_confirmed`, `driver_arriving`, `driver_arrived`,
    /// `booking_completed`, `booking_cancelled`, `payment_receipt`, `general`.
    required String type,

    /// Linked booking id, when the event relates to a specific journey.
    String? bookingId,

    /// Whether the customer has opened/read this notification.
    @Default(false) bool read,
  }) = _NotificationItem;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);
}
