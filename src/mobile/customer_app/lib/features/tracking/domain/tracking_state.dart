import 'package:freezed_annotation/freezed_annotation.dart';

import 'booking_status.dart';

part 'tracking_state.freezed.dart';
part 'tracking_state.g.dart';

/// Live tracking snapshot for a single booking. Emitted continuously by the
/// [TrackingRepository] stream as the booking progresses through its
/// [BookingStatus] lifecycle.
@freezed
abstract class TrackingState with _$TrackingState {
  const factory TrackingState({
    required String bookingId,
    required BookingStatus status,

    /// Present once a driver is allocated; null beforehand.
    DriverInfo? driver,

    /// Minutes until the driver reaches the pickup, when known.
    int? etaMinutes,
  }) = _TrackingState;

  factory TrackingState.fromJson(Map<String, dynamic> json) =>
      _$TrackingStateFromJson(json);
}

/// The driver assigned to a booking, including their live position.
@freezed
abstract class DriverInfo with _$DriverInfo {
  const factory DriverInfo({
    required String name,
    required String vehicle,
    required String plate,
    required double lat,
    required double lng,

    /// ARGB colour value the operator assigned this driver (matches the
    /// driver-colour dots used across the platform). Rendered via
    /// `Color(colorValue)` in presentation.
    required int colorValue,
  }) = _DriverInfo;

  factory DriverInfo.fromJson(Map<String, dynamic> json) =>
      _$DriverInfoFromJson(json);
}
