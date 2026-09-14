import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_prefs.freezed.dart';
part 'notification_prefs.g.dart';

/// Per-category push mute toggles. `true` means the customer wants to *receive*
/// that category (i.e. it is NOT muted). Mirrors the admin notification
/// preference categories so the dispatch side stays consistent.
@freezed
abstract class NotificationPrefs with _$NotificationPrefs {
  const factory NotificationPrefs({
    @Default(true) bool cashBooking,
    @Default(true) bool webBooking,
    @Default(true) bool cancellations,
    @Default(true) bool jobTimeouts,
  }) = _NotificationPrefs;

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) =>
      _$NotificationPrefsFromJson(json);
}
