import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TripStatus { idle, offered, enRouteToPickup, arrived, onTrip, complete }

class TripDetails {
  final String id;
  final String pickupAddress;
  final String dropoffAddress;
  final double fare;
  final String paymentType;

  const TripDetails({
    required this.id,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.fare,
    required this.paymentType,
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
  TripNotifier() : super(const TripState(status: TripStatus.idle));

  void offerJob(TripDetails trip) {
    state = TripState(status: TripStatus.offered, currentTrip: trip);
  }

  void acceptJob() {
    if (state.currentTrip != null) {
      state = state.copyWith(status: TripStatus.enRouteToPickup);
    }
  }

  void rejectJob() {
    state = const TripState(status: TripStatus.idle);
  }

  void markArrived() {
    if (state.status == TripStatus.enRouteToPickup) {
      state = state.copyWith(status: TripStatus.arrived);
    }
  }

  void startTrip() {
    if (state.status == TripStatus.arrived) {
      state = state.copyWith(status: TripStatus.onTrip);
    }
  }

  void completeTrip() {
    if (state.status == TripStatus.onTrip) {
      state = state.copyWith(status: TripStatus.complete);
    }
  }

  void finishShiftItem() {
    state = const TripState(status: TripStatus.idle);
  }
}

final tripProvider = StateNotifierProvider<TripNotifier, TripState>((ref) {
  return TripNotifier();
});
