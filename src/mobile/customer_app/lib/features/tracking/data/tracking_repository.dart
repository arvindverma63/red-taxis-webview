import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/session/session_controller.dart';
import '../domain/booking_status.dart';
import '../domain/tracking_state.dart';

/// Source of live booking-tracking updates.
///
/// Real-time (B5/B6): subscribes to the customer's Pusher private channel
/// `private-customer-{userId}` (authed via `POST /api/v2/pusher/auth`) and folds
/// inbound `booking-status` events onto [TrackingState]. The initial state is
/// fetched from `GET /api/v2/customers/me/bookings/{id}`.
///
/// Live driver-GPS movement (B7) is published by the driver app and arrives on
/// the same channel as `driver` data once that integration lands; the UI already
/// renders it when present.
///
/// In the CORS-blocked web preview (`PREVIEW_MOCKS=true`) [watch] emits a
/// realistic time-based progression instead so the screen is demoable offline.
class TrackingRepository {
  TrackingRepository(this._ref);

  final Ref _ref;

  Dio get _dio => _ref.read(dioProvider);

  PusherChannelsFlutter? _pusher;
  Future<void>? _connecting;
  StreamController<Map<String, dynamic>>? _events;

  /// Broadcast stream of decoded `booking-status` event payloads.
  Stream<Map<String, dynamic>> get _statusEvents {
    _events ??= StreamController<Map<String, dynamic>>.broadcast();
    return _events!.stream;
  }

  /// Streams [TrackingState] updates for [bookingId].
  Stream<TrackingState> watch(String bookingId) async* {
    if (AppConfig.previewMocks) {
      yield* _mockProgression(bookingId);
      return;
    }

    // 1. Seed with the booking's current status.
    var current = await _fetchInitial(bookingId);
    yield current;

    // Terminal states never change again.
    if (current.status == BookingStatus.completed ||
        current.status == BookingStatus.cancelled) {
      return;
    }

    // 2. Connect and forward live status events for this booking.
    await _ensureConnected();
    await for (final data in _statusEvents) {
      final evt = (data['bookingId'] ?? '').toString();
      final req = (data['requestId'] ?? '').toString();
      if (evt != bookingId && req != bookingId) continue;

      final status = _mapStatus(data['status']?.toString());
      if (status == null) continue;

      current = current.copyWith(
        status: status,
        driver: _parseDriver(data['driver']) ?? current.driver,
        etaMinutes: (data['etaMinutes'] as num?)?.toInt() ?? current.etaMinutes,
      );
      yield current;

      if (status == BookingStatus.completed ||
          status == BookingStatus.cancelled) {
        return;
      }
    }
  }

  /// Fetches the booking's current status to seed the stream.
  Future<TrackingState> _fetchInitial(String bookingId) async {
    try {
      final res = await _dio.get<dynamic>('/api/v2/customers/me/bookings/$bookingId');
      final body = res.data;
      final map = (body is Map && body['data'] is Map)
          ? body['data'] as Map<String, dynamic>
          : (body as Map<String, dynamic>);
      return TrackingState(
        bookingId: bookingId,
        status: _mapStatus(map['status']?.toString()) ?? BookingStatus.requested,
      );
    } catch (_) {
      // Unknown — assume freshly requested; live events will correct it.
      return TrackingState(bookingId: bookingId, status: BookingStatus.requested);
    }
  }

  /// Initialises Pusher once and subscribes to the customer's private channel.
  Future<void> _ensureConnected() => _connecting ??= _connect();

  Future<void> _connect() async {
    final userId = _ref.read(currentUserProvider)?.userId;
    if (userId == null) return; // not signed in — nothing to subscribe to.

    final config = AppConfig.fromEnvironment();
    final pusher = PusherChannelsFlutter.getInstance();
    _pusher = pusher;

    await pusher.init(
      apiKey: config.pusherKey,
      cluster: config.pusherCluster,
      onEvent: _onEvent,
      onAuthorizer: (channelName, socketId, options) async {
        final res = await _dio.post<dynamic>(
          '/api/v2/pusher/auth',
          data: {'socketId': socketId, 'channelName': channelName},
        );
        final data = res.data;
        if (data is Map<String, dynamic>) return data;
        if (data is String) return jsonDecode(data) as Map<String, dynamic>;
        return <String, dynamic>{};
      },
    );

    await pusher.subscribe(channelName: 'private-customer-$userId');
    await pusher.connect();
  }

  void _onEvent(PusherEvent event) {
    if (event.eventName != 'booking-status') return;
    final raw = event.data;
    if (raw == null || (raw is String && raw.isEmpty)) return;
    try {
      final map = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      _events?.add(map);
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  /// Submits a cancellation for the tracked booking (B4).
  Future<void> cancelBooking(String id) async {
    await _dio.post<dynamic>('/api/v2/customers/me/bookings/$id/cancel');
  }

  /// Releases the Pusher connection (called when tracking is no longer needed).
  Future<void> dispose() async {
    try {
      await _pusher?.disconnect();
    } catch (_) {/* best-effort */}
    await _events?.close();
    _events = null;
    _connecting = null;
  }

  BookingStatus? _mapStatus(String? s) => switch (s) {
        'requested' => BookingStatus.requested,
        'confirmed' => BookingStatus.confirmed,
        'allocated' => BookingStatus.allocated,
        'arriving' => BookingStatus.arriving,
        'arrived' => BookingStatus.arrived,
        'inProgress' || 'in-progress' || 'in_progress' => BookingStatus.inProgress,
        'completed' => BookingStatus.completed,
        'cancelled' || 'canceled' => BookingStatus.cancelled,
        _ => null,
      };

  DriverInfo? _parseDriver(dynamic d) {
    if (d is! Map) return null;
    final m = Map<String, dynamic>.from(d);
    final name = m['name']?.toString();
    if (name == null || name.isEmpty) return null;
    return DriverInfo(
      name: name,
      vehicle: (m['vehicle'] ?? '').toString(),
      plate: (m['plate'] ?? '').toString(),
      lat: (m['lat'] as num?)?.toDouble() ?? 0,
      lng: (m['lng'] as num?)?.toDouble() ?? 0,
      colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF2E90FA,
    );
  }

  // ── Preview-only mock progression (PREVIEW_MOCKS=true) ────────────────────
  static const double _pickupLat = 51.0058;
  static const double _pickupLng = -2.1916;
  static const DriverInfo _mockDriver = DriverInfo(
    name: 'James Carter',
    vehicle: 'Toyota Prius',
    plate: 'AC21 TXI',
    lat: 51.0142,
    lng: -2.2080,
    colorValue: 0xFF2E90FA,
  );

  Stream<TrackingState> _mockProgression(String bookingId) async* {
    yield TrackingState(bookingId: bookingId, status: BookingStatus.requested);
    await Future<void>.delayed(const Duration(seconds: 2));
    yield TrackingState(bookingId: bookingId, status: BookingStatus.confirmed);
    await Future<void>.delayed(const Duration(seconds: 2));
    yield TrackingState(
      bookingId: bookingId,
      status: BookingStatus.allocated,
      driver: _mockDriver,
      etaMinutes: 6,
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    yield TrackingState(
      bookingId: bookingId,
      status: BookingStatus.arriving,
      driver: _mockDriver.copyWith(lat: _pickupLat, lng: _pickupLng),
      etaMinutes: 1,
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    yield TrackingState(
      bookingId: bookingId,
      status: BookingStatus.arrived,
      driver: _mockDriver.copyWith(lat: _pickupLat, lng: _pickupLng),
      etaMinutes: 0,
    );
  }
}

/// Singleton repository provider.
final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => TrackingRepository(ref),
);
