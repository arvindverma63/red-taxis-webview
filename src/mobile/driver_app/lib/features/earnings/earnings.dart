import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EarningRecord {
  final String id;
  final DateTime date;
  final double amount;
  final String tripDescription;

  const EarningRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.tripDescription,
  });
}

class EarningsState {
  final List<EarningRecord> history;
  final double todayTotal;

  const EarningsState({
    required this.history,
    required this.todayTotal,
  });
}

class EarningsNotifier extends StateNotifier<EarningsState> {
  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(
    baseUrl: 'https://staging-api.redtaxi.co.uk',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  EarningsNotifier()
      : super(const EarningsState(history: [], todayTotal: 0.0)) {
    loadEarnings();
  }

  Future<void> loadEarnings() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null || token == 'simulated_jwt_token_123') {
        _loadMockEarnings();
        return;
      }

      final response = await _dio.get(
        '/api/DriverApp/CompletedJobs',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final List<dynamic> data = response.data ?? [];
      final List<EarningRecord> records = [];

      for (var job in data) {
        final amount = (job['fare'] ?? job['amount'] ?? job['price'] ?? 0.0).toDouble();
        final pickup = job['pickupAddress'] ?? job['pickup'] ?? 'Unknown Pickup';
        final dropoff = job['dropoffAddress'] ?? job['dropoff'] ?? 'Unknown Dropoff';
        final time = job['bookingTime'] ?? job['time'] ?? '00:00';
        final dateStr = job['bookingDate'] ?? job['date'];
        
        DateTime parsedDate = DateTime.now();
        if (dateStr != null) {
          try {
            parsedDate = DateTime.parse('$dateStr $time');
          } catch (_) {
            try {
              parsedDate = DateTime.parse(dateStr);
            } catch (_) {}
          }
        }

        records.add(EarningRecord(
          id: (job['bookingNo'] ?? job['id'] ?? '').toString(),
          date: parsedDate,
          amount: amount,
          tripDescription: 'Pickup: $pickup, Dropoff: $dropoff',
        ));
      }

      double todayTotal = records.fold(0.0, (prev, element) => prev + element.amount);
      state = EarningsState(
        history: records,
        todayTotal: todayTotal,
      );
    } catch (e) {
      _loadMockEarnings();
    }
  }

  void _loadMockEarnings() {
    final now = DateTime.now();
    final records = [
      EarningRecord(
        id: '1',
        date: now.subtract(const Duration(hours: 1)),
        amount: 24.50,
        tripDescription: 'Pickup: Heathrow Airport, Dropoff: London Central',
      ),
      EarningRecord(
        id: '2',
        date: now.subtract(const Duration(hours: 3)),
        amount: 15.00,
        tripDescription: 'Pickup: Wembley Stadium, Dropoff: Harrow',
      ),
    ];

    double todayTotal = records.fold(0.0, (prev, element) => prev + element.amount);

    state = EarningsState(
      history: records,
      todayTotal: todayTotal,
    );
  }

  void addRecord(EarningRecord record) {
    final updatedHistory = List<EarningRecord>.from(state.history)..insert(0, record);
    state = EarningsState(
      history: updatedHistory,
      todayTotal: state.todayTotal + record.amount,
    );
  }
}

final earningsProvider =
    StateNotifierProvider<EarningsNotifier, EarningsState>((ref) {
  return EarningsNotifier();
});
