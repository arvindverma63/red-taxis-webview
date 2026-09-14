import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/domain/place.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/address_suggestion.dart';
import '../domain/quote.dart';

/// Talks to the v2 booking-related endpoints: address autocomplete, address
/// resolution, fare quoting and the (still-to-be-built) customer booking
/// request. Holds the Google-style session token across a search→resolve pair
/// so the backend can group billable autocomplete calls.
class BookingRepository {
  BookingRepository(this._dio);

  final Dio _dio;

  /// Session token shared across the current search→resolve cycle. Reset by
  /// the controller after a resolve completes a selection.
  String? _sessionToken;

  String? get sessionToken => _sessionToken;

  /// Autocomplete for [query]. Optional [biasPostTown]/[biasLonLat] nudge
  /// results toward the user's area. Returns suggestions and stashes the
  /// server-issued session token for the matching [resolveAddress] call.
  Future<List<AddressSuggestion>> searchAddress(
    String query, {
    int limit = 6,
    String? biasPostTown,
    ({double lon, double lat})? biasLonLat,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/api/v2/address/search',
        data: {
          'query': query,
          if (_sessionToken != null) 'sessionToken': _sessionToken,
          'limit': limit,
          if (biasPostTown != null) 'biasPostTown': biasPostTown,
          if (biasLonLat != null)
            'biasLonLat': {'lon': biasLonLat.lon, 'lat': biasLonLat.lat},
        },
      );
      return unwrapV2<List<AddressSuggestion>>(res.data, (data) {
        if (data is Map<String, dynamic>) {
          final token = data['sessionToken'];
          if (token is String && token.isNotEmpty) _sessionToken = token;
          return parseList(
            data['suggestions'],
            (m) => AddressSuggestion.fromJson(_mapSuggestion(m)),
          );
        }
        return const [];
      });
    } catch (_) {
      // Falls back to local Dorset results when the API is unreachable — e.g.
      // the web preview (CORS) or offline. On device the real call succeeds.
      return _mockSearch(query);
    }
  }

  /// Resolves a suggestion [placeId] to a full [Place] (with lat/lng + postcode)
  /// using the active session token, then clears the token so the next search
  /// starts a fresh billable session.
  Future<Place> resolveAddress(String placeId) async {
    try {
      final res = await _dio.get<dynamic>(
        '/api/v2/address/resolve',
        queryParameters: {
          'id': placeId,
          if (_sessionToken != null) 'sessionToken': _sessionToken,
        },
      );
      final place = unwrapV2<Place>(res.data, (data) {
        final map = data as Map<String, dynamic>;
        return _mapResolvedPlace(map);
      });
      _sessionToken = null; // selection complete — end the session
      return place;
    } catch (_) {
      // Keep _sessionToken on failure: a failed resolve must not poison a
      // retry of the same selection (clearing it caused tokenless retries to
      // hit the backend's SESSION_REQUIRED). It's replaced by the next search
      // or cleared on the next successful resolve.
      // Resolve from the mock cache when the API is unreachable (web preview).
      final cached = _mockResolveCache[placeId];
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Fares for the current route. [accountNo] is `9999` for cash; account users
  /// pass their account number. Postcodes come from the resolved pickup/dropoff
  /// [Place]s; [viaPostcodes] are optional stop-offs.
  Future<Quote> getQuote({
    required String accountNo,
    required DateTime pickupDateTime,
    required int passengers,
    required String pickupPostcode,
    required String destinationPostcode,
    List<String> viaPostcodes = const [],
    bool priceFromBase = false,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/api/v2/pricing/quote',
        data: {
          'accountNo': accountNo,
          'pickupDateTime': pickupDateTime.toUtc().toIso8601String(),
          'passengers': passengers,
          'pickupPostcode': pickupPostcode,
          'destinationPostcode': destinationPostcode,
          'viaPostcodes': viaPostcodes,
          'priceFromBase': priceFromBase,
        },
      );
      return unwrapV2<Quote>(res.data, (data) {
        final map = data as Map<String, dynamic>;
        return Quote(
          priceCash: _toDouble(map['priceDriver']),
          priceAccount: _toDouble(map['priceAccount']),
          totalMileage: _toDouble(map['totalMileage']),
          totalMinutes: _toInt(map['totalMinutes']),
          mileageText: (map['mileageText'] as String?) ?? '',
          durationText: (map['durationText'] as String?) ?? '',
        );
      });
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Submits the customer's booking request to `POST /api/v2/bookings/request`
  /// (B2). Returns `(requestId, status)`. A failed submit throws [ApiException]
  /// so the UI never shows a fake "booked" — only the preview build mocks it.
  Future<({String requestId, String status})> createRequest(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<dynamic>(
        '/api/v2/bookings/request',
        data: body,
      );
      return unwrapV2<({String requestId, String status})>(res.data, (data) {
        final map = data as Map<String, dynamic>;
        return (
          requestId: (map['requestId'] ?? '').toString(),
          status: (map['status'] ?? 'pending').toString(),
        );
      });
    } on DioException catch (e) {
      if (AppConfig.previewMocks) {
        return (requestId: _mockRequestId(), status: 'pending');
      }
      throw _asApiException(e);
    }
  }

  // ── mapping helpers ───────────────────────────────────────────────────

  /// Normalises the API suggestion shape `{id, label, secondaryText, postcode}`
  /// (also tolerating older `place_id`/`description`) to the freezed model.
  Map<String, dynamic> _mapSuggestion(Map<String, dynamic> m) {
    final id = (m['id'] ?? m['place_id'] ?? m['placeId'] ?? '').toString();
    final label =
        (m['label'] ?? m['description'] ?? m['mainText'] ?? '').toString();
    final parts = label.split(',');
    final mainText = parts.first.trim();
    final secondary = (m['secondaryText'] ?? m['secondary_text'] ??
            (parts.length > 1 ? parts.sublist(1).join(',').trim() : ''))
        .toString();
    return {
      'placeId': id,
      'description': label,
      'mainText': mainText.isEmpty ? label : mainText,
      'secondaryText': secondary,
      'postcode': m['postcode'],
    };
  }

  /// Maps the `resolve` response to the core [Place].
  ///
  /// The live v2 endpoint returns the `ResolvedAddress` shape (camelCase):
  /// `{displayLabel, placeName, formattedAddress, postcode, line1, line2,
  /// townCity, county, lat, lng}`. We also tolerate the older nested
  /// `{address:{...}, coordinates:{lon,lat}}` and flat `{label, description}`
  /// shapes so the mock/preview path and any legacy response still resolve.
  Place _mapResolvedPlace(Map<String, dynamic> m) {
    final address = (m['address'] as Map<String, dynamic>?) ?? const {};
    final coords = (m['coordinates'] as Map<String, dynamic>?) ?? const {};

    // Address line: prefer the flat ResolvedAddress fields, fall back to the
    // nested `address` object.
    final line1 =
        (m['line1'] ?? address['address1'] as String?)?.toString().trim() ?? '';
    final line2 =
        (m['line2'] ?? address['address2'] as String?)?.toString().trim() ?? '';
    final city =
        (m['townCity'] ?? address['city'] as String?)?.toString().trim() ?? '';
    final addressLine =
        [line1, line2, city].where((s) => s.isNotEmpty).join(', ');

    // Human-readable label shown across review/confirm/activity/details.
    final label = (m['displayLabel'] ??
                m['label'] ??
                m['description'] ??
                m['formattedAddress'])
            ?.toString()
            .trim() ??
        '';

    return Place(
      description: label.isNotEmpty
          ? label
          : (addressLine.isNotEmpty ? addressLine : 'Selected location'),
      postcode: (m['postcode'] ?? address['postcode'])?.toString().trim(),
      lat: _toNullableDouble(coords['lat'] ?? m['lat']),
      lng: _toNullableDouble(coords['lon'] ?? m['lng'] ?? m['lon']),
      addressLine: addressLine.isNotEmpty ? addressLine : label,
    );
  }

  // ── Offline / preview mock (Dorset) ───────────────────────────────────────

  /// Sample places covering Ace's heartland, used as the search fallback.
  static const _mockPlaces = <Place>[
    Place(description: 'Gillingham Station, Station Road, Gillingham', postcode: 'SP8 4QT', lat: 51.0382, lng: -2.2718, addressLine: 'Station Road, Gillingham'),
    Place(description: 'Gillingham High Street, Gillingham', postcode: 'SP8 4AA', lat: 51.0376, lng: -2.2745, addressLine: 'High Street, Gillingham'),
    Place(description: 'Shaftesbury, High Street', postcode: 'SP7 8JE', lat: 51.0058, lng: -2.1972, addressLine: 'High Street, Shaftesbury'),
    Place(description: 'Gold Hill, Shaftesbury', postcode: 'SP7 8JW', lat: 51.0042, lng: -2.1989, addressLine: 'Gold Hill, Shaftesbury'),
    Place(description: 'The Square, Mere', postcode: 'BA12 6JJ', lat: 51.0915, lng: -2.2706, addressLine: 'The Square, Mere'),
    Place(description: 'Wincanton, Market Place', postcode: 'BA9 9LD', lat: 51.0557, lng: -2.4071, addressLine: 'Market Place, Wincanton'),
    Place(description: 'Sturminster Newton, Market Cross', postcode: 'DT10 1AN', lat: 50.9247, lng: -2.3104, addressLine: 'Market Cross, Sturminster Newton'),
    Place(description: 'Salisbury District Hospital', postcode: 'SP2 8BJ', lat: 51.0432, lng: -1.7876, addressLine: 'Odstock Road, Salisbury'),
    Place(description: 'Yeovil Hospital', postcode: 'BA21 4AT', lat: 50.9389, lng: -2.6361, addressLine: 'Higher Kingston, Yeovil'),
    Place(description: 'Bournemouth Airport', postcode: 'BH23 6SE', lat: 50.7800, lng: -1.8425, addressLine: 'Christchurch'),
  ];

  final Map<String, Place> _mockResolveCache = {};

  List<AddressSuggestion> _mockSearch(String query) {
    final q = query.trim().toLowerCase();
    final matches = _mockPlaces.where((p) {
      final hay = '${p.description} ${p.postcode ?? ''}'.toLowerCase();
      return q.isEmpty || hay.contains(q);
    }).toList();
    final pool = matches.isEmpty ? _mockPlaces : matches;
    final out = <AddressSuggestion>[];
    for (var i = 0; i < pool.length; i++) {
      final p = pool[i];
      final id = 'mock:$i:${p.postcode}';
      _mockResolveCache[id] = p;
      final parts = p.description.split(',');
      out.add(AddressSuggestion(
        placeId: id,
        description: p.description,
        mainText: parts.first.trim(),
        secondaryText: parts.length > 1
            ? parts.sublist(1).join(',').trim()
            : (p.postcode ?? ''),
        postcode: p.postcode,
      ));
    }
    return out;
  }

  ApiException _asApiException(DioException e) {
    final err = e.error;
    if (err is ApiException) return err;
    return ApiException(
      e.message ?? 'Something went wrong. Please try again.',
      statusCode: e.response?.statusCode,
    );
  }

  String _mockRequestId() {
    final rng = Random();
    final n = rng.nextInt(900000) + 100000;
    return 'REQ-MOCK-$n';
  }

  static double _toDouble(dynamic v) => _toNullableDouble(v) ?? 0;

  static double? _toNullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(dioProvider));
});
