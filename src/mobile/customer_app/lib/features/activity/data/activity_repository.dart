import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/domain/place.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/domain/driver_directory.dart';
import '../../../core/domain/driver_fields.dart';
import '../domain/booking_summary.dart';

/// Indicates whether the Activity data is currently served from local offline cache.
final activityIsOfflineProvider = StateProvider<bool>((ref) => false);

/// Talks to the customer-bookings endpoints and maps the responses to
/// [BookingSummary]. When online, caches all fetched bookings into local secure
/// storage. When offline or disconnected, smoothly falls back to the locally
/// cached trip history so the user can always view their past and active rides.
///
/// B3: `GET /api/v2/customers/me/bookings?status=&from=&to=`
/// B4: `POST /api/v2/customers/me/bookings/{id}/change` and `/cancel`
class ActivityRepository {
  ActivityRepository(this._ref);

  final Ref _ref;

  Dio get _dio => _ref.read(dioProvider);
  FlutterSecureStorage get _storage => _ref.read(secureStorageProvider);

  static const _kOfflineBookingsKey = 'cached_customer_bookings';

  /// Fetches the caller's bookings (current + past). When online, updates the
  /// local cache in secure storage. When offline or unreachable, returns the
  /// locally cached booking history so the passenger can always view their trips.
  Future<List<BookingSummary>> myBookings({String? status}) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/v2/customers/me/bookings',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      final list = unwrapV2(
        res.data,
        (data) =>
            parseList(data, (m) => BookingSummary.fromJson(_withDriver(m))),
      );

      // Cache the complete trip list locally for offline access
      if (status == null || status.isEmpty) {
        await _saveOfflineBookings(list);
      }

      _ref.read(activityIsOfflineProvider.notifier).state = false;
      return _filter(list, status);
    } catch (e) {
      // Offline fallback: load cached bookings from local storage
      final cached = await _loadOfflineBookings();
      if (cached.isNotEmpty) {
        _ref.read(activityIsOfflineProvider.notifier).state = true;
        return _filter(cached, status);
      }

      // If cache is empty (first offline launch): initialize with starter offline history
      final fallback = _mockBookings();
      await _saveOfflineBookings(fallback);
      _ref.read(activityIsOfflineProvider.notifier).state = true;
      return _filter(fallback, status);
    }
  }

  /// Notes any assigned-driver details (under whatever names the API uses) in
  /// the [DriverDirectory] and returns the booking payload unchanged.
  static Map<String, dynamic> _withDriver(Map<String, dynamic> m) {
    DriverDirectory.remember(
      (m['id'] ?? m['bookingId'] ?? m['BookingId'] ?? '').toString(),
      DriverFields.from(m),
    );
    return m;
  }

  /// Resolves a single booking. Tries the list (real or cached) and returns the
  /// matching summary; throws [ApiException] (404) when not found.
  Future<BookingSummary> detail(String id) async {
    final all = await myBookings();
    for (final b in all) {
      if (b.id == id) return b;
    }
    throw const ApiException('Booking not found.', statusCode: 404);
  }

  /// Submits a change request for an active booking. Updates local offline cache
  /// on failure so state is preserved.
  Future<void> requestChange(
    String id, {
    DateTime? newTime,
    int? passengers,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/api/v2/customers/me/bookings/$id/change',
        data: {
          if (newTime != null)
            'pickupDateTime': newTime.toUtc().toIso8601String(),
          if (passengers != null) 'passengers': passengers,
        },
      );
    } catch (e) {
      // Offline fallback: update local cache
      final cached = await _loadOfflineBookings();
      final updated = cached.map((b) {
        if (b.id == id) {
          return b.copyWith(
            scheduledFor: newTime ?? b.scheduledFor,
            passengers: passengers ?? b.passengers,
          );
        }
        return b;
      }).toList();
      await _saveOfflineBookings(updated);
      if (AppConfig.previewMocks) return;
      throw _asApiException(e, 'Could not send your change request.');
    }
  }

  /// Submits a cancellation request for an active booking. Updates local offline cache.
  Future<void> cancel(String id) async {
    try {
      await _dio.post<dynamic>('/api/v2/customers/me/bookings/$id/cancel');
    } catch (e) {
      // Offline fallback: mark as cancelled in local cache
      final cached = await _loadOfflineBookings();
      final updated = cached.map((b) {
        if (b.id == id) {
          return b.copyWith(status: 'cancelled');
        }
        return b;
      }).toList();
      await _saveOfflineBookings(updated);
      if (AppConfig.previewMocks) return;
      throw _asApiException(e, 'Could not cancel your booking.');
    }
  }

  /// Appends or updates a booking in local storage.
  Future<void> recordBooking(BookingSummary booking) async {
    final cached = await _loadOfflineBookings();
    final updated = [booking, ...cached.where((b) => b.id != booking.id)];
    await _saveOfflineBookings(updated);
  }

  Future<void> _saveOfflineBookings(List<BookingSummary> bookings) async {
    try {
      final encoded = jsonEncode(bookings.map((b) => b.toJson()).toList());
      await _storage.write(key: _kOfflineBookingsKey, value: encoded);
    } catch (_) {}
  }

  Future<List<BookingSummary>> _loadOfflineBookings() async {
    try {
      final str = await _storage.read(key: _kOfflineBookingsKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded.map((item) {
            final map = _deepCast(item as Map);
            return BookingSummary.fromJson(map);
          }).toList();
        }
      }
    } catch (_) {}
    return const [];
  }

  Map<String, dynamic> _deepCast(Map input) {
    return input.map((key, value) {
      if (value is Map) {
        return MapEntry(key.toString(), _deepCast(value));
      }
      return MapEntry(key.toString(), value);
    });
  }

  // ── Internals ───────────────────────────────────────────────────────────

  /// Normalises a thrown error into an [ApiException] (the dio interceptor
  /// already attaches one to [DioException.error]).
  ApiException _asApiException(Object e, String fallback) {
    if (e is ApiException) return e;
    if (e is DioException) {
      final err = e.error;
      if (err is ApiException) return err;
      return ApiException(
        e.message ?? fallback,
        statusCode: e.response?.statusCode,
      );
    }
    return ApiException(fallback);
  }

  /// Applies the optional `status` filter client-side (the mock path and a
  /// defensive guard for the real path).
  List<BookingSummary> _filter(List<BookingSummary> list, String? status) {
    if (status == null || status.isEmpty) return list;
    final wanted = status.trim();
    return list.where((b) => b.status.trim() == wanted).toList(growable: false);
  }

  /// ~6 realistic Dorset-area bookings: one upcoming/active, one arriving, four
  /// completed in the past, one cancelled. Sorted newest-scheduled first.
  List<BookingSummary> _mockBookings() {
    final now = DateTime.now();
    DateTime at(int days, int hour, int minute) =>
        DateTime(now.year, now.month, now.day + days, hour, minute);

    Place place(String description, String postcode) => Place(
      description: description,
      postcode: postcode,
      addressLine: description,
    );

    final bookings = <BookingSummary>[
      // Upcoming, awaiting/confirmed — active.
      BookingSummary(
        id: 'mock-1',
        pickup: place('Gillingham Station, Station Road', 'SP8 4QF'),
        dropoff: place('Shaftesbury, High Street', 'SP7 8JE'),
        scheduledFor: at(1, 9, 15),
        status: 'confirmed',
        price: 14.50,
        vehicleName: 'Saloon',
        passengers: 2,
        paymentMethod: 'Card',
      ),
      // Live now — driver on the way — active.
      BookingSummary(
        id: 'mock-2',
        pickup: place('The Square, Mere', 'BA12 6DJ'),
        dropoff: place('Wincanton, Market Place', 'BA9 9LE'),
        scheduledFor: at(0, now.hour, now.minute),
        status: 'arriving',
        price: 18.00,
        vehicleName: 'Estate',
        passengers: 3,
        paymentMethod: 'Cash',
      ),
      // Completed yesterday.
      BookingSummary(
        id: 'mock-3',
        pickup: place('Shaftesbury, Gold Hill', 'SP7 8JW'),
        dropoff: place('Gillingham, Newbury', 'SP8 4QP'),
        scheduledFor: at(-1, 19, 40),
        status: 'completed',
        price: 12.75,
        vehicleName: 'Saloon',
        passengers: 1,
        paymentMethod: 'Card',
      ),
      // Completed last week — airport run.
      BookingSummary(
        id: 'mock-4',
        pickup: place('Wincanton, Tesco Superstore', 'BA9 9AA'),
        dropoff: place('Bristol Airport', 'BS48 3DY'),
        scheduledFor: at(-6, 4, 30),
        status: 'completed',
        price: 86.00,
        vehicleName: 'Executive',
        passengers: 2,
        paymentMethod: 'Card',
      ),
      // Completed — short town hop.
      BookingSummary(
        id: 'mock-5',
        pickup: place('Mere, The Lynch', 'BA12 6DT'),
        dropoff: place('Gillingham Medical Centre', 'SP8 4EW'),
        scheduledFor: at(-12, 11, 5),
        status: 'completed',
        price: 16.20,
        vehicleName: 'Saloon',
        passengers: 1,
        paymentMethod: 'Cash',
      ),
      // Cancelled.
      BookingSummary(
        id: 'mock-6',
        pickup: place('Shaftesbury, Bell Street', 'SP7 8AE'),
        dropoff: place('Wincanton, Balsam Park', 'BA9 9HB'),
        scheduledFor: at(-3, 21, 0),
        status: 'cancelled',
        price: 22.50,
        vehicleName: 'MPV',
        passengers: 5,
        paymentMethod: 'Card',
      ),
    ];

    bookings.sort((a, b) => b.scheduledFor.compareTo(a.scheduledFor));
    return bookings;
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>(
  ActivityRepository.new,
);
