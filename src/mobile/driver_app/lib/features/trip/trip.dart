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
  final String guid;
  final String pickupAddress;
  final String dropoffAddress;
  final double fare;
  final String paymentType;
  final String vehicleType;
  final String passenger;
  final String notes;

  const TripDetails({
    required this.id,
    this.guid = '',
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
        checkActiveJob();
      } else {
        _stopPolling();
      }
    });

    // Check initial state
    final shift = _ref.read(shiftProvider);
    if (shift.status == ShiftStatus.online) {
      _startPolling();
      checkActiveJob();
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
      if (responseData['bookingNo'] != null || responseData['bookingId'] != null || responseData['id'] != null) {
        return [responseData];
      }
    }
    return [];
  }

  TripDetails _mapJobToDetails(Map<String, dynamic> job, String fallbackId, {String fallbackGuid = ''}) {
    final fare = double.tryParse((job['price'] ?? job['Price'] ?? job['fare'] ?? job['Fare'] ?? job['amount'] ?? job['Amount'] ?? job['driverPrice'] ?? job['DriverPrice'] ?? '0.0').toString()) ?? 0.0;
    final pickup = (job['pickupAddress'] ?? job['PickupAddress'] ?? job['pickup'] ?? job['Pickup'] ?? job['from'] ?? job['From'] ?? 'Pickup address').toString();
    final dropoff = (job['destinationAddress'] ?? job['DestinationAddress'] ?? job['dropoff'] ?? job['Dropoff'] ?? job['dropoffAddress'] ?? job['DropoffAddress'] ?? job['to'] ?? job['To'] ?? 'Dropoff destination').toString();
    
    // Payment scope mapping
    String paymentType = (job['paymentType'] ?? job['PaymentType'] ?? job['paymentMethod'] ?? job['PaymentMethod'] ?? '').toString();
    if (paymentType.isEmpty && (job['scope'] != null || job['Scope'] != null)) {
      final scope = int.tryParse((job['scope'] ?? job['Scope']).toString()) ?? 0;
      switch (scope) {
        case 0:
          paymentType = 'Cash';
          break;
        case 1:
          paymentType = 'Account';
          break;
        case 2:
          paymentType = 'Rank';
          break;
        case 4:
          paymentType = 'Card';
          break;
        default:
          paymentType = 'Cash';
          break;
      }
    }
    if (paymentType.isEmpty) paymentType = 'Cash';

    final id = (job['bookingId'] ?? job['BookingId'] ?? job['bookingNo'] ?? job['BookingNo'] ?? job['id'] ?? job['Id'] ?? fallbackId).toString();
    final guid = (job['guid'] ?? job['Guid'] ?? job['notificationId'] ?? job['notification_id'] ?? job['NotificationId'] ?? fallbackGuid).toString();
    final vehicleType = (job['vehicleType'] ?? job['VehicleType'] ?? job['vehicle'] ?? job['Vehicle'] ?? 'Standard Saloon').toString();
    final passenger = (job['passengerName'] ?? job['PassengerName'] ?? job['passenger'] ?? job['Passenger'] ?? job['customerName'] ?? job['CustomerName'] ?? 'Passenger').toString();
    final notes = (job['details'] ?? job['Details'] ?? job['notes'] ?? job['Notes'] ?? job['comment'] ?? job['Comment'] ?? job['specialRequirements'] ?? job['SpecialRequirements'] ?? '').toString();

    return TripDetails(
      id: id,
      guid: guid,
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

  Future<void> checkActiveJob() async {
    // Only check if currently idle
    if (state.status != TripStatus.idle) return;

    final auth = _ref.read(authProvider);
    final token = auth.token;
    if (token == null) return;

    try {
      final response = await _dio.get(
        '/api/DriverApp/GetActiveJob',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final jobData = response.data;
      if (jobData != null) {
        String activeBookingId = '';
        Map<String, dynamic>? activeJobMap;

        if (jobData is Map) {
          activeJobMap = Map<String, dynamic>.from(jobData);
          activeBookingId = (activeJobMap['bookingId'] ?? activeJobMap['BookingId'] ?? activeJobMap['bookingNo'] ?? activeJobMap['BookingNo'] ?? activeJobMap['id'] ?? activeJobMap['Id'] ?? '').toString();
        } else if (jobData is int || jobData is String) {
          activeBookingId = jobData.toString();
        } else if (jobData is Map && (jobData['value'] != null || jobData['data'] != null)) {
          final nested = jobData['value'] ?? jobData['data'];
          if (nested is int || nested is String) {
            activeBookingId = nested.toString();
          } else if (nested is Map) {
            activeJobMap = Map<String, dynamic>.from(nested);
            activeBookingId = (activeJobMap['bookingId'] ?? activeJobMap['BookingId'] ?? '').toString();
          }
        }

        if (activeBookingId.isNotEmpty && activeBookingId != '0') {
          Map<String, dynamic>? finalJobData = activeJobMap;

          if (finalJobData == null) {
            try {
              final detailsRes = await _dio.get(
                '/api/Bookings/FindById',
                queryParameters: {'bookingId': activeBookingId},
                options: Options(headers: {'Authorization': 'Bearer $token'}),
              );
              if (detailsRes.data != null && detailsRes.data is Map) {
                finalJobData = Map<String, dynamic>.from(detailsRes.data);
              }
            } catch (e) {
              debugPrint("[TripNotifier] Fetch active job details error: $e");
            }
          }

          if (finalJobData != null) {
            final details = _mapJobToDetails(finalJobData, activeBookingId);
            final statusVal = int.tryParse((finalJobData['status'] ?? finalJobData['Status'] ?? '0').toString()) ?? 0;
            TripStatus activeStatus = TripStatus.enRouteToPickup;
            if (statusVal == 3006) {
              activeStatus = TripStatus.onTrip;
            } else if (statusVal == 3) {
              activeStatus = TripStatus.arrived;
            }

            state = TripState(status: activeStatus, currentTrip: details);
            debugPrint("[TripNotifier] Restored active trip: ${details.id} status: $activeStatus");
          }
        }
      }
    } catch (e) {
      debugPrint("[TripNotifier] checkActiveJob error: $e");
    }
  }

  bool _isMockTrip(String jobId) {
    return jobId.startsWith('sim-');
  }

  void offerJob(TripDetails trip) {
    state = TripState(status: TripStatus.offered, currentTrip: trip);
  }

  Future<void> fetchAndOfferJob(String bookingId, {String guid = '', TripDetails? fallbackDetails}) async {
    if (state.status == TripStatus.offered) {
      debugPrint("[TripNotifier] Ignoring job offer because an offer is already active on screen");
      return;
    }

    final initialTrip = fallbackDetails ??
        TripDetails(
          id: bookingId,
          guid: guid,
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

    Map<String, dynamic>? jobData;

    // 1. Try FindById?bookingId=
    if (bookingId.isNotEmpty) {
      try {
        final res = await _dio.get(
          '/api/Bookings/FindById',
          queryParameters: {'bookingId': bookingId},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (res.data != null && res.data is Map) {
          jobData = Map<String, dynamic>.from(res.data);
        }
      } catch (e) {
        debugPrint("[TripNotifier] FindById error: $e");
      }
    }

    // 2. Try RetrieveJobOffer?guid=
    if (jobData == null && guid.isNotEmpty) {
      try {
        final res = await _dio.get(
          '/api/DriverApp/RetrieveJobOffer',
          queryParameters: {'guid': guid},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (res.data != null && res.data is Map) {
          jobData = Map<String, dynamic>.from(res.data);
        }
      } catch (e) {
        debugPrint("[TripNotifier] RetrieveJobOffer error: $e");
      }
    }

    // 3. Try GetJobOffers
    if (jobData == null) {
      try {
        final res = await _dio.get(
          '/api/DriverApp/GetJobOffers',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final list = _parseJobsList(res.data);
        if (list.isNotEmpty) {
          final matching = list.firstWhere(
            (j) => (j['bookingNo'] ?? j['bookingId'] ?? j['id'] ?? '').toString() == bookingId,
            orElse: () => list.first,
          );
          jobData = Map<String, dynamic>.from(matching);
        }
      } catch (e) {
        debugPrint("[TripNotifier] GetJobOffers error: $e");
      }
    }

    if (jobData != null) {
      final details = _mapJobToDetails(jobData, bookingId, fallbackGuid: guid);
      offerJob(details);
    }
  }

  Future<void> acceptJob() async {
    if (state.currentTrip != null) {
      final jobId = state.currentTrip!.id;

      // Close/dismiss job offer overlay by returning to idle state
      state = const TripState(status: TripStatus.idle);

      final bookingIdInt = int.tryParse(jobId) ?? 0;
      if (bookingIdInt > 0 && !_isMockTrip(jobId)) {
        setActiveJob(bookingIdInt);
      }
    }
  }

  Future<void> rejectJob() async {
    if (state.currentTrip != null) {
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
        setActiveJob(0);
        try {
          await _dio.post(
            '/api/DriverApp/CompleteJob',
            data: {
              'bookingId': int.tryParse(jobId) ?? 0,
              'BookingId': int.tryParse(jobId) ?? 0,
              'driverPrice': fare,
              'DriverPrice': fare,
              'waitingTime': 0,
              'WaitingTime': 0,
              'parkingCharge': 0.0,
              'ParkingCharge': 0.0,
              'accountPrice': 0.0,
              'AccountPrice': 0.0,
              'tip': 0.0,
              'Tip': 0.0,
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
    final jobId = state.currentTrip?.id;
    if (jobId != null && !_isMockTrip(jobId)) {
      setActiveJob(0);
    }
    state = const TripState(status: TripStatus.idle);
  }

  Future<void> setActiveJob(int bookingId) async {
    final auth = _ref.read(authProvider);
    final token = auth.token;

    try {
      await _dio.post(
        '/api/DriverApp/SetActiveJob',
        queryParameters: {'bookingId': bookingId},
        data: {
          'bookingId': bookingId,
          'BookingId': bookingId,
        },
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
      debugPrint("[TripNotifier] SetActiveJob success: $bookingId");
    } catch (e) {
      debugPrint("[TripNotifier] SetActiveJob error: $e");
    }
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
