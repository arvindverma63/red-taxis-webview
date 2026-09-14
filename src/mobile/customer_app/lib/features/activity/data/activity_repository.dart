import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/domain/place.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/booking_summary.dart';

/// Talks to the (pending) B3/B4 customer-bookings endpoints and maps the
/// responses to [BookingSummary]. Until the backend is built, every call falls
/// back to realistic mock data so the Activity screens are fully populated in
/// preview.
///
/// B3: `GET /api/v2/customers/me/bookings?status=&from=&to=`
/// B4: `POST /api/v2/customers/me/bookings/{id}/change` and `/cancel`
class ActivityRepository {
  ActivityRepository(this._ref);

  final Ref _ref;

  Dio get _dio => _ref.read(dioProvider);

  /// Fetches the caller's bookings (current + past). Falls back to mock data
  /// when the endpoint is not yet built (404/501) or unreachable (network).
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
        (data) => parseList(data, BookingSummary.fromJson),
      );
      // A real-but-empty response is still valid — don't mask it with mocks.
      return _filter(list, status);
    } catch (e) {
      if (AppConfig.previewMocks) {
        return _filter(_mockBookings(), status);
      }
      throw _asApiException(e, 'Could not load your bookings.');
    }
  }

  /// Resolves a single booking. Tries the list (real or mock) and returns the
  /// matching summary; throws [ApiException] (404) when not found.
  Future<BookingSummary> detail(String id) async {
    final all = await myBookings();
    for (final b in all) {
      if (b.id == id) return b;
    }
    throw const ApiException('Booking not found.', statusCode: 404);
  }

  /// Submits a change request for an active booking (B4). Mocked to succeed
  /// until the endpoint exists.
  Future<void> requestChange(
    String id, {
    DateTime? newTime,
    int? passengers,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/api/v2/customers/me/bookings/$id/change',
        data: {
          if (newTime != null) 'pickupDateTime': newTime.toUtc().toIso8601String(),
          if (passengers != null) 'passengers': passengers,
        },
      );
    } catch (e) {
      if (AppConfig.previewMocks) return;
      throw _asApiException(e, 'Could not send your change request.');
    }
  }

  /// Submits a cancellation request for an active booking (B4). Mocked to
  /// succeed until the endpoint exists.
  Future<void> cancel(String id) async {
    try {
      await _dio.post<dynamic>('/api/v2/customers/me/bookings/$id/cancel');
    } catch (e) {
      if (AppConfig.previewMocks) return;
      throw _asApiException(e, 'Could not cancel your booking.');
    }
  }

  // ── Internals ───────────────────────────────────────────────────────────

  /// Normalises a thrown error into an [ApiException] (the dio interceptor
  /// already attaches one to [DioException.error]).
  ApiException _asApiException(Object e, String fallback) {
    if (e is ApiException) return e;
    if (e is DioException) {
      final err = e.error;
      if (err is ApiException) return err;
      return ApiException(e.message ?? fallback, statusCode: e.response?.statusCode);
    }
    return ApiException(fallback);
  }

  /// Applies the optional `status` filter client-side (the mock path and a
  /// defensive guard for the real path).
  List<BookingSummary> _filter(List<BookingSummary> list, String? status) {
    if (status == null || status.isEmpty) return list;
    final wanted = status.trim();
    return list
        .where((b) => b.status.trim() == wanted)
        .toList(growable: false);
  }

  /// ~6 realistic Dorset-area bookings: one upcoming/active, one arriving, four
  /// completed in the past, one cancelled. Sorted newest-scheduled first.
  List<BookingSummary> _mockBookings() {
    final now = DateTime.now();
    DateTime at(int days, int hour, int minute) =>
        DateTime(now.year, now.month, now.day + days, hour, minute);

    Place place(String description, String postcode) =>
        Place(description: description, postcode: postcode, addressLine: description);

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

final activityRepositoryProvider =
    Provider<ActivityRepository>(ActivityRepository.new);
