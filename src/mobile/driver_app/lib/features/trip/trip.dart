import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:driver_app/features/shift/shift.dart';

enum TripStatus { idle, offered, enRouteToPickup, arrived, onTrip, complete }

class TripDetails {
  final String id;
  final String pickupAddress;
  final String dropoffAddress;
  final double fare;
  final String paymentType;
  final String vehicleType;
  final String passenger;
  final String notes;

  const TripDetails({
    required this.id,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.fare,
    required this.paymentType,
    this.vehicleType = 'Standard Saloon',
    this.passenger = 'Passenger',
    this.notes = '',
  });
}

class TripState {
  final TripStatus status;
  final TripDetails? currentTrip;

  const TripState({
    required this.status,
    this.currentTrip,
  });

  TripState copyWith({
    TripStatus? status,
    TripDetails? currentTrip,
  }) {
    return TripState(
      status: status ?? this.status,
      currentTrip: currentTrip ?? this.currentTrip,
    );
  }
}

class TripNotifier extends StateNotifier<TripState> {
  final Ref _ref;
  Timer? _pollTimer;

  final _dio = Dio(BaseOptions(
    baseUrl: 'https://staging-api.redtaxi.co.uk',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  TripNotifier(this._ref) : super(const TripState(status: TripStatus.idle)) {
    if (!kIsWeb) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[Dio/Trip] $obj'),
      ));
    }
    // Listen to shiftProvider to start/stop polling
    _ref.listen<ShiftState>(shiftProvider, (previous, next) {
      if (next.status == ShiftStatus.online) {
        _startPolling();
      } else {
        _stopPolling();
      }
    });

    // Check initial state
    final shift = _ref.read(shiftProvider);
    if (shift.status == ShiftStatus.online) {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollJobOffer());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  List<dynamic> _parseJobsList(dynamic responseData) {
    if (responseData == null) return [];
    if (responseData is List) return responseData;
    if (responseData is Map) {
      if (responseData['value'] is List) return responseData['value'];
      if (responseData['data'] is List) return responseData['data'];
      if (responseData['jobs'] is List) return responseData['jobs'];
      if (responseData['offers'] is List) return responseData['offers'];
      if (responseData['bookingNo'] != null || responseData['id'] != null) {
        return [responseData];
      }
    }
    return [];
  }

  TripDetails _mapJobToDetails(Map<String, dynamic> job, String fallbackId) {
    final fare = double.tryParse((job['fare'] ?? job['amount'] ?? job['price'] ?? job['driverPrice'] ?? '0.0').toString()) ?? 0.0;
    final pickup = (job['pickupAddress'] ?? job['pickup'] ?? job['from'] ?? 'Pickup address').toString();
    final dropoff = (job['destinationAddress'] ?? job['dropoff'] ?? job['dropoffAddress'] ?? job['to'] ?? 'Dropoff destination').toString();
    final paymentType = (job['paymentType'] ?? job['paymentMethod'] ?? 'Cash').toString();
    final id = (job['bookingNo'] ?? job['bookingId'] ?? job['id'] ?? fallbackId).toString();
    final vehicleType = (job['vehicleType'] ?? job['vehicle'] ?? 'Standard Saloon').toString();
    final passenger = (job['passengerName'] ?? job['passenger'] ?? job['customerName'] ?? 'Passenger').toString();
    final notes = (job['notes'] ?? job['comment'] ?? job['specialRequirements'] ?? '').toString();

    return TripDetails(
      id: id,
      pickupAddress: pickup,
      dropoffAddress: dropoff,
      fare: fare,
      paymentType: paymentType,
      vehicleType: vehicleType,
      passenger: passenger,
      notes: notes,
    );
  }

  Future<void> _pollJobOffer() async {
    // Only poll if currently idle
    if (state.status != TripStatus.idle) return;

    final auth = _ref.read(authProvider);
    final token = auth.token;
    if (token == null) return;

    try {
      final response = await _dio.get(
        '/api/DriverApp/GetJobOffers',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final List<dynamic> data = _parseJobsList(response.data);
      if (data.isNotEmpty) {
        final job = Map<String, dynamic>.from(data.first);
        final details = _mapJobToDetails(job, '');
        offerJob(details);
      }
    } catch (e) {
      debugPrint("[TripNotifier] Background poll error: $e");
    }
  }

  bool _isMockTrip(String jobId) {
    return jobId.startsWith('sim-');
  }

  void offerJob(TripDetails trip) {
    state = TripState(status: TripStatus.offered, currentTrip: trip);
  }

  Future<void> fetchAndOfferJob(String bookingId, {TripDetails? fallbackDetails}) async {
    final initialTrip = fallbackDetails ??
        TripDetails(
          id: bookingId,
          pickupAddress: 'Pickup location',
          dropoffAddress: 'Dropoff destination',
          fare: 0.0,
          paymentType: 'Cash',
          passenger: 'Passenger',
        );

    // Immediately display the offer overlay to the driver without delay
    offerJob(initialTrip);

    final auth = _ref.read(authProvider);
    final token = auth.token;
    if (token == null) return;

    try {
      final response = await _dio.get(
        '/api/DriverApp/GetJobOffers',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final List<dynamic> data = _parseJobsList(response.data);
      if (data.isNotEmpty) {
        final matchingJob = data.firstWhere(
          (j) => (j['bookingNo'] ?? j['bookingId'] ?? j['id'] ?? '').toString() == bookingId,
          orElse: () => data.first,
        );
        final jobMap = Map<String, dynamic>.from(matchingJob);
        final details = _mapJobToDetails(jobMap, bookingId);
        offerJob(details);
      }
    } catch (e) {
      debugPrint("[TripNotifier] fetchAndOfferJob API error: $e");
    }
  }

  Future<void> acceptJob() async {
    if (state.currentTrip != null) {
      final auth = _ref.read(authProvider);
      final token = auth.token;
      final jobId = state.currentTrip!.id;

      // Update state immediately so UI transitions instantly
      state = state.copyWith(status: TripStatus.enRouteToPickup);

      if (!_isMockTrip(jobId)) {
        try {
          await _dio.get(
            '/api/DriverApp/JobOfferReply',
            queryParameters: {
              'jobno': int.tryParse(jobId) ?? 0,
              'response': 2000, // AppJobOffer.Accept
            },
            options: Options(
              headers: token != null ? {'Authorization': 'Bearer $token'} : null,
            ),
          );
        } catch (e) {
          debugPrint("[TripNotifier] JobOfferReply API error: $e");
        }
      }
    }
  }

  Future<void> rejectJob() async {
    if (state.currentTrip != null) {
      final auth = _ref.read(authProvider);
      final token = auth.token;
      final jobId = state.currentTrip!.id;

      if (!_isMockTrip(jobId)) {
        try {
          await _dio.get(
            '/api/DriverApp/JobOfferReply',
            queryParameters: {
              'jobno': int.tryParse(jobId) ?? 0,
              'response': 2001, // AppJobOffer.Reject
            },
            options: Options(
              headers: token != null ? {'Authorization': 'Bearer $token'} : null,
            ),
          );
        } catch (e) {
          // Proceed
        }
      }

      state = const TripState(status: TripStatus.idle);
    }
  }

  Future<void> markArrived() async {
    if (state.status == TripStatus.enRouteToPickup && state.currentTrip != null) {
      final auth = _ref.read(authProvider);
      final token = auth.token;
      final jobId = state.currentTrip!.id;

      if (!_isMockTrip(jobId)) {
        try {
          await _dio.get(
            '/api/DriverApp/Arrived',
            queryParameters: {
              'bookingId': int.tryParse(jobId) ?? 0,
            },
            options: Options(
              headers: token != null ? {'Authorization': 'Bearer $token'} : null,
            ),
          );
        } catch (e) {
          // Proceed
        }
      }

      state = state.copyWith(status: TripStatus.arrived);
    }
  }

  Future<void> startTrip() async {
    if (state.status == TripStatus.arrived && state.currentTrip != null) {
      final auth = _ref.read(authProvider);
      final token = auth.token;
      final jobId = state.currentTrip!.id;

      if (!_isMockTrip(jobId)) {
        try {
          await _dio.get(
            '/api/DriverApp/JobStatusReply',
            queryParameters: {
              'jobno': int.tryParse(jobId) ?? 0,
              'status': 3006, // AppJobStatus.OnTrip
            },
            options: Options(
              headers: token != null ? {'Authorization': 'Bearer $token'} : null,
            ),
          );
        } catch (e) {
          // Proceed
        }
      }

      state = state.copyWith(status: TripStatus.onTrip);
    }
  }

  Future<void> completeTrip() async {
    if (state.status == TripStatus.onTrip && state.currentTrip != null) {
      final auth = _ref.read(authProvider);
      final token = auth.token;
      final jobId = state.currentTrip!.id;
      final fare = state.currentTrip!.fare;

      if (!_isMockTrip(jobId)) {
        try {
          await _dio.post(
            '/api/DriverApp/CompleteJob',
            data: {
              'bookingId': int.tryParse(jobId) ?? 0,
              'driverPrice': fare,
              'waitingTime': 0,
              'parkingCharge': 0.0,
              'accountPrice': 0.0,
              'tip': 0.0,
            },
            options: Options(
              headers: token != null ? {'Authorization': 'Bearer $token'} : null,
            ),
          );
        } catch (e) {
          // Proceed
        }
      }

      state = state.copyWith(status: TripStatus.complete);
    }
  }

  void finishShiftItem() {
    state = const TripState(status: TripStatus.idle);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final tripProvider = StateNotifierProvider<TripNotifier, TripState>((ref) {
  return TripNotifier(ref);
});
