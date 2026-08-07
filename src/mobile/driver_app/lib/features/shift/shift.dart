import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ShiftStatus { offline, online }

class ShiftState {
  final ShiftStatus status;
  final DateTime? startTime;

  const ShiftState({
    required this.status,
    this.startTime,
  });

  ShiftState copyWith({
    ShiftStatus? status,
    DateTime? startTime,
  }) {
    return ShiftState(
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
    );
  }
}

class ShiftNotifier extends StateNotifier<ShiftState> {
  ShiftNotifier() : super(const ShiftState(status: ShiftStatus.offline));

  void goOnline() {
    state = ShiftState(
      status: ShiftStatus.online,
      startTime: DateTime.now(),
    );
  }

  void goOffline() {
    state = const ShiftState(status: ShiftStatus.offline);
  }
}

final shiftProvider = StateNotifierProvider<ShiftNotifier, ShiftState>((ref) {
  return ShiftNotifier();
});
