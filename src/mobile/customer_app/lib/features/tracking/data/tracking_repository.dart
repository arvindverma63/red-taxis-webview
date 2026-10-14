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
  ///
  /// Polls the backend server every 5 seconds for live status updates, driver
  /// assignment, and vehicle telemetry while also listening for real-time Pusher
  /// channel events.
  Stream<TrackingState> watch(String bookingId) async* {
    if (AppConfig.previewMocks) {
      yield* _mockProgression(bookingId);
      return;
    }

    // 1. Fetch current status from the server immediately.
    var current = await fetchBookingState(bookingId);
    yield current;

    // Terminal states never change again.
    if (current.status == BookingStatus.completed ||
        current.status == BookingStatus.cancelled) {
      return;
    }

    // 2. Connect Pusher in the background (best effort for immediate push events).
    _ensureConnected().catchError((_) {});

    // Listen for incoming Pusher status events and queue them.
    final pusherQueue = <TrackingState>[];
    StreamSubscription? pusherSub;
    try {
      pusherSub = _statusEvents.listen((data) {
        final evt = (data['bookingId'] ?? data['BookingId'] ?? '').toString();
        final req = (data['requestId'] ?? data['RequestId'] ?? '').toString();
        if (evt != bookingId && req != bookingId) return;

        final status = _mapStatus(data['status'] ?? data['Status']);
        if (status != null) {
          current = current.copyWith(
            status: status,
            driver: _parseDriver(data['driver'] ?? data['Driver'], data) ??
                current.driver,
            etaMinutes:
                (data['etaMinutes'] ?? data['eta'] as num?)?.toInt() ??
                    current.etaMinutes,
          );
          pusherQueue.add(current);
        }
      });

      // 3. Poll backend every 5 seconds until terminal status.
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 5));

        // Flush any Pusher events that arrived during the wait.
        while (pusherQueue.isNotEmpty) {
          final next = pusherQueue.removeAt(0);
          yield next;
          if (next.status == BookingStatus.completed ||
              next.status == BookingStatus.cancelled) {
            return;
          }
        }

        // Active server query every 5 seconds.
        try {
          final serverState = await fetchBookingState(bookingId);
          if (serverState.status != current.status ||
              serverState.driver != current.driver ||
              serverState.etaMinutes != current.etaMinutes) {
            current = serverState;
            yield current;
          }
        } catch (_) {
          // Best-effort polling; ignore transient network drops.
        }

        if (current.status == BookingStatus.completed ||
            current.status == BookingStatus.cancelled) {
          return;
        }
      }
    } finally {
      await pusherSub?.cancel();
    }
  }

  /// Fetches the booking's latest status and driver assignment from the server.
  /// Tries the single-booking endpoint, the customer booking list, and the
  /// core FindById endpoint to ensure resilient resolution across all backend variants.
  Future<TrackingState> fetchBookingState(String bookingId) async {
    Map<String, dynamic>? data;

    // 1. Primary: /api/v2/customers/me/bookings/$bookingId
    try {
      final res = await _dio.get<dynamic>(
        '/api/v2/customers/me/bookings/$bookingId',
      );
      if (res.data != null) {
        if (res.data is Map && res.data['data'] is Map) {
          data = Map<String, dynamic>.from(res.data['data'] as Map);
        } else if (res.data is Map && res.data['value'] is Map) {
          data = Map<String, dynamic>.from(res.data['value'] as Map);
        } else if (res.data is Map) {
          data = Map<String, dynamic>.from(res.data as Map);
        }
      }
    } catch (_) {
      // Fall through to list or FindById
    }

    // 2. Secondary: search in customer's bookings list /api/v2/customers/me/bookings
    if (data == null || data.isEmpty) {
      try {
        final res = await _dio.get<dynamic>(
          '/api/v2/customers/me/bookings',
        );
        final body = res.data;
        List? list;
        if (body is List) {
          list = body;
        } else if (body is Map) {
          list = (body['data'] is List)
              ? body['data'] as List
              : (body['bookings'] is List
                  ? body['bookings'] as List
                  : (body['value'] is List ? body['value'] as List : null));
        }
        if (list != null) {
          for (final item in list) {
            if (item is Map) {
              final id = (item['id'] ??
                      item['bookingId'] ??
                      item['BookingId'] ??
                      '')
                  .toString();
              if (id == bookingId) {
                data = Map<String, dynamic>.from(item);
                break;
              }
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: /api/Bookings/FindById?bookingId=
    if (data == null || data.isEmpty) {
      try {
        final res = await _dio.get<dynamic>(
          '/api/Bookings/FindById',
          queryParameters: {'bookingId': bookingId},
        );
        if (res.data != null) {
          if (res.data is Map && res.data['data'] is Map) {
            data = Map<String, dynamic>.from(res.data['data'] as Map);
          } else if (res.data is Map) {
            data = Map<String, dynamic>.from(res.data as Map);
          }
        }
      } catch (_) {}
    }

    if (data != null && data.isNotEmpty) {
      final rawStatus = data['status'] ??
          data['Status'] ??
          data['bookingStatus'] ??
          data['BookingStatus'] ??
          data['jobStatus'] ??
          data['JobStatus'];

      final status = _mapStatus(rawStatus) ?? BookingStatus.requested;
      final driver = _parseDriver(data['driver'] ?? data['Driver'], data);
      final rawEta =
          data['etaMinutes'] ?? data['eta'] ?? data['durationMinutes'];
      final eta = (rawEta is num)
          ? rawEta.toInt()
          : (int.tryParse(rawEta?.toString() ?? ''));

      return TrackingState(
        bookingId: bookingId,
        status: status,
        driver: driver,
        etaMinutes: eta,
      );
    }

    return TrackingState(bookingId: bookingId, status: BookingStatus.requested);
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

  BookingStatus? _mapStatus(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim().toLowerCase();

    // Handle numeric status codes (Ace Taxis / server enum values)
    final n = int.tryParse(s);
    if (n != null) {
      if (n == 0 || n == 100) return BookingStatus.requested;
      if (n == 1) return BookingStatus.confirmed;
      if (n == 2 || n == 2000) return BookingStatus.allocated;
      if (n == 3005) return BookingStatus.arrived;
      if (n == 3006) return BookingStatus.inProgress;
      if (n == 3) return BookingStatus.arrived;
      if (n == 4) return BookingStatus.inProgress;
      if (n == 5 || n == 6) return BookingStatus.completed;
      if (n == -1 || n == 7 || n == 8) return BookingStatus.cancelled;
    }

    if (s == 'requested' ||
        s == 'request_sent' ||
        s == 'pending' ||
        s == 'new' ||
        s.contains('request')) {
      return BookingStatus.requested;
    }
    if (s == 'confirmed' || s == 'accepted') {
      return BookingStatus.confirmed;
    }
    if (s == 'allocated' ||
        s.contains('allocat') ||
        s == 'driver_assigned' ||
        s == 'assigned' ||
        s == 'dispatched') {
      return BookingStatus.allocated;
    }
    if (s == 'arriving' ||
        s == 'on_the_way' ||
        s == 'on_way' ||
        s.contains('en_route') ||
        s.contains('enroute') ||
        s.contains('heading')) {
      return BookingStatus.arriving;
    }
    if (s == 'arrived' || s == 'at_pickup' || s == 'waiting') {
      return BookingStatus.arrived;
    }
    if (s == 'inprogress' ||
        s == 'in_progress' ||
        s == 'in-progress' ||
        s == 'on_trip' ||
        s == 'ontrip' ||
        s == 'pob' ||
        s == 'picked_up' ||
        s.contains('trip')) {
      return BookingStatus.inProgress;
    }
    if (s == 'completed' ||
        s == 'finished' ||
        s == 'done' ||
        s == 'complete') {
      return BookingStatus.completed;
    }
    if (s == 'cancelled' ||
        s == 'canceled' ||
        s == 'rejected' ||
        s == 'declined' ||
        s == 'void') {
      return BookingStatus.cancelled;
    }
    return null;
  }

  DriverInfo? _parseDriver(dynamic d, [Map<String, dynamic>? parent]) {
    String? name;
    String vehicle = '';
    String plate = '';
    double lat = 0.0;
    double lng = 0.0;
    int colorValue = 0xFF2E90FA;

    if (d is Map) {
      final m = Map<String, dynamic>.from(d);
      name = m['name']?.toString() ??
          m['fullName']?.toString() ??
          m['fullname']?.toString() ??
          m['FullName']?.toString();
      vehicle = (m['vehicle'] ??
              m['vehicleModel'] ??
              m['VehicleModel'] ??
              m['model'] ??
              '')
          .toString();
      plate = (m['plate'] ??
              m['vehicleReg'] ??
              m['VehicleReg'] ??
              m['regNumber'] ??
              m['RegNumber'] ??
              '')
          .toString();
      lat = (m['lat'] as num?)?.toDouble() ??
          (m['latitude'] as num?)?.toDouble() ??
          0.0;
      lng = (m['lng'] as num?)?.toDouble() ??
          (m['longitude'] as num?)?.toDouble() ??
          0.0;
      colorValue = (m['colorValue'] as num?)?.toInt() ?? 0xFF2E90FA;
    }

    if ((name == null || name.isEmpty) && parent != null) {
      name = parent['driverName']?.toString() ??
          parent['driver_name']?.toString() ??
          parent['DriverName']?.toString() ??
          parent['driver']?.toString();
      if (name != null && name.startsWith('{')) {
        name = null;
      }
      vehicle = (parent['vehicleModel'] ??
              parent['VehicleModel'] ??
              parent['vehicle'] ??
              parent['vehicleName'] ??
              parent['vehicleType'] ??
              '')
          .toString();
      plate = (parent['vehicleReg'] ??
              parent['VehicleReg'] ??
              parent['plate'] ??
              parent['registration'] ??
              parent['regNumber'] ??
              '')
          .toString();
      lat = (parent['driverLat'] ??
              parent['driver_lat'] ??
              parent['DriverLat'] as num?)
          ?.toDouble() ??
          lat;
      lng = (parent['driverLng'] ??
              parent['driver_lng'] ??
              parent['DriverLng'] as num?)
          ?.toDouble() ??
          lng;
    }

    if (name == null || name.trim().isEmpty) return null;

    return DriverInfo(
      name: name.trim(),
      vehicle: vehicle.isNotEmpty ? vehicle.trim() : 'Saloon Taxi',
      plate: plate.trim(),
      lat: lat,
      lng: lng,
      colorValue: colorValue,
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
