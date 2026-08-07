import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  EarningsNotifier()
      : super(const EarningsState(history: [], todayTotal: 0.0));

  void loadEarnings() {
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
  return EarningsNotifier()..loadEarnings();
});
