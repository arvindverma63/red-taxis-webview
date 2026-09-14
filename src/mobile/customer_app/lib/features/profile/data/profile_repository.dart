import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/domain/auth_user.dart';
import '../../../core/domain/place.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/session/session_controller.dart';
import '../domain/notification_item.dart';
import '../domain/notification_prefs.dart';
import '../domain/payment_card.dart';

/// Talks to the customer profile, saved-address, payment and notification
/// endpoints.
///
/// NOTE: the backend endpoints below are NOT built yet (B11 profile/addresses,
/// B9 payments). Each method calls the documented route but falls back to
/// realistic mock data held in-memory so the screens are fully functional ahead
/// of the API. Replace the fallbacks with the live responses once the endpoints
/// ship — search for TODO(B11) / TODO(B9).
class ProfileRepository {
  ProfileRepository(this._ref);

  final Ref _ref;

  Dio get _dio => _ref.read(dioProvider);

  // ── In-memory mock stores (survive while the provider is alive) ──────────
  // These let CRUD + toggles actually mutate state and reflect in the UI even
  // though no backend persists them yet.
  List<SavedPlace>? _addresses;
  List<PaymentCard>? _cards;
  List<NotificationItem>? _notifications;
  NotificationPrefs _prefs = const NotificationPrefs();

  // ── Profile ─────────────────────────────────────────────────────────────

  /// GET `/api/v2/customers/me/profile` (B11). Maps the profile to [AuthUser]
  /// and refreshes the session. Falls back to the session user offline.
  Future<AuthUser> getProfile() async {
    try {
      final res = await _dio.get<dynamic>('/api/v2/customers/me/profile');
      final user = unwrapV2<AuthUser>(res.data, (data) {
        final m = data as Map<String, dynamic>;
        return AuthUser(
          userId: (m['userId'] as num).toInt(),
          username: (m['username'] ?? '').toString(),
          fullName: (m['fullName'] ?? '').toString(),
          email: m['email'] as String?,
          phoneNumber: m['phoneNumber'] as String?,
          role: (m['role'] ?? 'Customer').toString(),
          isAccount: (m['role'] ?? '').toString().toLowerCase() == 'account',
        );
      });
      _ref.read(sessionProvider.notifier).setUser(user);
      return user;
    } catch (e) {
      // Profile screens should still render — fall back to the live session user.
      final current = _ref.read(currentUserProvider);
      if (current != null) return current;
      if (AppConfig.previewMocks) {
        return const AuthUser(
          userId: 1001,
          username: 'jordan.blake',
          fullName: 'Jordan Blake',
          email: 'jordan.blake@example.com',
          phoneNumber: '07700 900123',
          role: 'Customer',
        );
      }
      throw _asApiException(e, 'Could not load your profile.');
    }
  }

  /// PUT `/api/v2/customers/me/profile` (B11). Persists name/phone, then syncs
  /// the app-wide session so identity reflects everywhere.
  Future<AuthUser> updateProfile({
    String? fullName,
    String? phoneNumber,
  }) async {
    try {
      final res = await _dio.put<dynamic>(
        '/api/v2/customers/me/profile',
        data: {
          if (fullName != null) 'fullName': fullName,
          if (phoneNumber != null) 'phoneNumber': phoneNumber,
        },
      );
      final user = unwrapV2<AuthUser>(res.data, (data) {
        final m = data as Map<String, dynamic>;
        return AuthUser(
          userId: (m['userId'] as num).toInt(),
          username: (m['username'] ?? '').toString(),
          fullName: (m['fullName'] ?? '').toString(),
          email: m['email'] as String?,
          phoneNumber: m['phoneNumber'] as String?,
          role: (m['role'] ?? 'Customer').toString(),
          isAccount: (m['role'] ?? '').toString().toLowerCase() == 'account',
        );
      });
      _ref.read(sessionProvider.notifier).setUser(user);
      return user;
    } catch (e) {
      if (AppConfig.previewMocks) {
        final current = await getProfile();
        final updated = current.copyWith(
          fullName: fullName ?? current.fullName,
          phoneNumber: phoneNumber ?? current.phoneNumber,
        );
        _ref.read(sessionProvider.notifier).setUser(updated);
        return updated;
      }
      throw _asApiException(e, 'Could not save your profile.');
    }
  }

  // ── Saved addresses ───────────────────────────────────────────────────────

  /// GET `/api/v2/customers/me/addresses` (B11).
  Future<List<SavedPlace>> addresses() async {
    try {
      final res = await _dio.get<dynamic>('/api/v2/customers/me/addresses');
      return unwrapV2<List<SavedPlace>>(
        res.data,
        (data) => parseList(data, SavedPlace.fromJson),
      );
    } catch (e) {
      if (AppConfig.previewMocks) {
        return _addresses ??= _mockAddresses();
      }
      throw _asApiException(e, 'Could not load your saved places.');
    }
  }

  /// POST `/api/v2/customers/me/addresses` (B11). Returns the updated list.
  Future<List<SavedPlace>> add(SavedPlace address) async {
    try {
      final res = await _dio.post<dynamic>(
        '/api/v2/customers/me/addresses',
        data: {
          'label': address.label,
          'description': address.place.description,
          'postcode': address.place.postcode,
          'lat': address.place.lat,
          'lng': address.place.lng,
          'addressLine': address.place.addressLine,
        },
      );
      return unwrapV2<List<SavedPlace>>(
        res.data,
        (data) => parseList(data, SavedPlace.fromJson),
      );
    } catch (e) {
      if (AppConfig.previewMocks) {
        final list = await addresses();
        return _addresses = [...list, address];
      }
      throw _asApiException(e, 'Could not save this place.');
    }
  }

  /// DELETE `/api/v2/customers/me/addresses/{id}` (B11). Returns the updated list.
  Future<List<SavedPlace>> remove(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/api/v2/customers/me/addresses/$id');
      return unwrapV2<List<SavedPlace>>(
        res.data,
        (data) => parseList(data, SavedPlace.fromJson),
      );
    } catch (e) {
      if (AppConfig.previewMocks) {
        final list = await addresses();
        return _addresses = list.where((a) => a.id != id).toList();
      }
      throw _asApiException(e, 'Could not remove this place.');
    }
  }

  ApiException _asApiException(Object e, String fallback) {
    if (e is ApiException) return e;
    if (e is DioException) {
      final err = e.error;
      if (err is ApiException) return err;
      return ApiException(e.message ?? fallback, statusCode: e.response?.statusCode);
    }
    return ApiException(fallback);
  }

  List<SavedPlace> _mockAddresses() => const [
        SavedPlace(
          id: 'home',
          label: 'Home',
          place: Place(
            description: '14 Riverside Gardens, Gillingham',
            postcode: 'SP8 4FA',
            addressLine: '14 Riverside Gardens, Gillingham',
            lat: 51.0376,
            lng: -2.2756,
          ),
        ),
        SavedPlace(
          id: 'work',
          label: 'Work',
          place: Place(
            description: 'Ace Taxis Office, Station Road, Gillingham',
            postcode: 'SP8 4QH',
            addressLine: 'Station Road, Gillingham',
            lat: 51.0382,
            lng: -2.2741,
          ),
        ),
      ];

  // ── Payment methods ───────────────────────────────────────────────────────

  /// Saved cards (Revolut-tokenised).
  Future<List<PaymentCard>> paymentCards() async {
    // TODO(B9): GET the customer's tokenised cards from the payments service.
    // Card payments aren't built yet (cash-only go-live), so real users have no
    // saved cards — return an empty list rather than fabricating ones. Demo
    // cards are only used in the CORS-blocked web preview / offline demos
    // (mirrors notifications()/addresses()).
    if (!AppConfig.previewMocks) {
      return _cards ??= const [];
    }
    return _cards ??= [
      const PaymentCard(
        id: 'card_visa_4242',
        brand: 'visa',
        last4: '4242',
        label: 'Personal Visa',
        isDefault: true,
      ),
      const PaymentCard(
        id: 'card_mc_8210',
        brand: 'mastercard',
        last4: '8210',
        label: 'Mastercard',
      ),
    ];
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<List<NotificationItem>> notifications() async {
    // TODO(B8/B11): GET the customer's notification inbox once it exists.
    // No backend yet: return an empty inbox so real users see the empty state
    // rather than fabricated events. Demo data is only used in the CORS-blocked
    // web preview / offline demos (mirrors addresses()/getProfile()).
    if (!AppConfig.previewMocks) {
      return _notifications ??= const [];
    }
    final now = DateTime.now();
    return _notifications ??= [
      NotificationItem(
        id: 'n1',
        title: 'Your driver is arriving',
        body: 'Sam is 2 minutes away in a silver Skoda Octavia (AE21 XYZ).',
        time: now.subtract(const Duration(minutes: 3)),
        type: 'driver_arriving',
        bookingId: 'BKG-10231',
      ),
      NotificationItem(
        id: 'n2',
        title: 'Booking confirmed',
        body: 'Your taxi from Home to Gillingham Station is booked for 14:30.',
        time: now.subtract(const Duration(hours: 2)),
        type: 'booking_confirmed',
        bookingId: 'BKG-10231',
        read: true,
      ),
      NotificationItem(
        id: 'n3',
        title: 'Payment receipt',
        body: 'We charged £12.40 to your Personal Visa for trip BKG-10044.',
        time: now.subtract(const Duration(days: 1, hours: 4)),
        type: 'payment_receipt',
        bookingId: 'BKG-10044',
        read: true,
      ),
      NotificationItem(
        id: 'n4',
        title: 'Trip completed',
        body: 'Hope you enjoyed your journey. Tap to rate your driver.',
        time: now.subtract(const Duration(days: 1, hours: 5)),
        type: 'booking_completed',
        bookingId: 'BKG-10044',
        read: true,
      ),
    ];
  }

  Future<List<NotificationItem>> markRead(String id) async {
    // TODO(B11): PATCH /notifications/{id} read=true on the server.
    final list = await notifications();
    _notifications = [
      for (final n in list)
        if (n.id == id) n.copyWith(read: true) else n,
    ];
    return _notifications!;
  }

  Future<List<NotificationItem>> clearAll() async {
    // TODO(B11): DELETE the inbox / mark all read server-side.
    _notifications = [];
    return _notifications!;
  }

  // ── Notification preferences ──────────────────────────────────────────────

  Future<NotificationPrefs> prefs() async {
    // TODO(B11): read persisted preferences from the profile endpoint.
    return _prefs;
  }

  Future<NotificationPrefs> savePrefs(NotificationPrefs prefs) async {
    // TODO(B11): PUT the preferences to the profile endpoint.
    return _prefs = prefs;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref),
);
