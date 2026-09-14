import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../booking/domain/booking_models.dart';

class RidesState {
  final CustomerBooking? currentActiveRide;
  final List<CustomerBooking> history;
  final bool isLoading;
  final int etaMinutes;

  const RidesState({
    this.currentActiveRide,
    this.history = const [],
    this.isLoading = false,
    this.etaMinutes = 4,
  });

  RidesState copyWith({
    CustomerBooking? currentActiveRide,
    List<CustomerBooking>? history,
    bool? isLoading,
    int? etaMinutes,
  }) {
    return RidesState(
      currentActiveRide: currentActiveRide ?? this.currentActiveRide,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      etaMinutes: etaMinutes ?? this.etaMinutes,
    );
  }
}

class RidesNotifier extends StateNotifier<RidesState> {
  RidesNotifier() : super(_initialState()) {
    _startSimulatedProgression();
  }

  static RidesState _initialState() {
    final now = DateTime.now();
    return RidesState(
      currentActiveRide: CustomerBooking(
        id: 'BK994821',
        pickupAddress: 'High Street, City Centre, SW1A 1AA',
        dropoffAddress: 'Terminal 2, Heathrow Airport, TW6 1EW',
        pickupTime: now,
        fare: 18.50,
        vehicleType: 'Saloon',
        status: 'driver_allocated',
        driverName: 'Mohammed Tariq',
        driverPhone: '07123 456789',
        vehicleReg: 'LD67 WRX',
        vehicleModel: 'Toyota Prius (Silver)',
        paymentMethod: 'cash',
        passengers: 2,
        luggage: 2,
      ),
      history: [
        CustomerBooking(
          id: 'BK993102',
          pickupAddress: '24 Elm Road, Suburb',
          dropoffAddress: 'Central Station, City',
          pickupTime: now.subtract(const Duration(days: 1, hours: 2)),
          fare: 12.00,
          vehicleType: 'Saloon',
          status: 'completed',
          driverName: 'Dave Smith',
          vehicleReg: 'EA21 KPL',
        ),
        CustomerBooking(
          id: 'BK992810',
          pickupAddress: 'Shopping Mall South Gate',
          dropoffAddress: 'The Grand Hotel, Promenade',
          pickupTime: now.subtract(const Duration(days: 3)),
          fare: 15.50,
          vehicleType: 'Executive',
          status: 'completed',
          driverName: 'James Wilson',
          vehicleReg: 'BV69 TZX',
        ),
        CustomerBooking(
          id: 'BK991544',
          pickupAddress: 'Victoria Hospital Entrance',
          dropoffAddress: 'Oak Street Apartments',
          pickupTime: now.subtract(const Duration(days: 6)),
          fare: 9.50,
          vehicleType: 'Saloon',
          status: 'cancelled',
        ),
      ],
    );
  }

  void _startSimulatedProgression() {
    // Progress demo active trip status gracefully
    Timer.periodic(const Duration(seconds: 25), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (state.currentActiveRide != null) {
        final current = state.currentActiveRide!;
        if (current.status == 'driver_allocated') {
          state = state.copyWith(
            currentActiveRide: current.copyWith(status: 'arrived'),
            etaMinutes: 0,
          );
        } else if (current.status == 'arrived') {
          state = state.copyWith(
            currentActiveRide: current.copyWith(status: 'on_trip'),
            etaMinutes: 14,
          );
        }
      }
    });
  }

  void cancelRide(String bookingId) {
    if (state.currentActiveRide?.id == bookingId) {
      final cancelled = state.currentActiveRide!.copyWith(status: 'cancelled');
      state = state.copyWith(
        currentActiveRide: null,
        history: [cancelled, ...state.history],
      );
    }
  }
}

final ridesProvider = StateNotifierProvider<RidesNotifier, RidesState>((ref) {
  return RidesNotifier();
});
