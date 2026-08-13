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

      final List<dynamic> data = response.data ?? [];
      if (data.isNotEmpty) {
        final job = data.first;
        final fare = (job['fare'] ?? job['amount'] ?? job['price'] ?? 0.0).toDouble();
        final pickup = job['pickupAddress'] ?? job['pickup'] ?? 'Unknown Pickup';
        final dropoff = job['destinationAddress'] ?? job['dropoff'] ?? job['dropoffAddress'] ?? 'Unknown Dropoff';
        final paymentType = job['paymentType'] ?? job['paymentMethod'] ?? 'Cash';
        final id = (job['bookingNo'] ?? job['id'] ?? '').toString();
        final vehicleType = job['vehicleType'] ?? 'Standard Saloon';
        final passenger = job['passengerName'] ?? job['passenger'] ?? 'Passenger';
        final notes = job['notes'] ?? job['comment'] ?? '';

        offerJob(TripDetails(
          id: id,
          pickupAddress: pickup,
          dropoffAddress: dropoff,
          fare: fare,
          paymentType: paymentType,
          vehicleType: vehicleType,
          passenger: passenger,
          notes: notes,
        ));
      }
    } catch (e) {
      // Ignore background poll errors
    }
  }

  bool _isMockTrip(String jobId) {
    return jobId.startsWith('sim-');
  }

  void offerJob(TripDetails trip) {
    state = TripState(status: TripStatus.offered, currentTrip: trip);
  }

  Future<void> acceptJob() async {
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
              'response': 2000, // AppJobOffer.Accept
            },
            options: Options(
              headers: token != null ? {'Authorization': 'Bearer $token'} : null,
            ),
          );
        } catch (e) {
          // Proceed anyway
        }
      }

      state = state.copyWith(status: TripStatus.enRouteToPickup);
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
