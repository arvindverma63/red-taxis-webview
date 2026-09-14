import 'package:flutter/material.dart';

enum VehicleClass { saloon, estate, executive, mpv6, mpv8 }

class VehicleOption {
  final VehicleClass type;
  final String name;
  final String description;
  final int capacity;
  final int luggageCapacity;
  final double basePrice;
  final IconData icon;

  const VehicleOption({
    required this.type,
    required this.name,
    required this.description,
    required this.capacity,
    required this.luggageCapacity,
    required this.basePrice,
    required this.icon,
  });

  static List<VehicleOption> get defaultOptions => const [
    VehicleOption(
      type: VehicleClass.saloon,
      name: 'Saloon',
      description: 'Standard 4-door sedan for everyday travel',
      capacity: 4,
      luggageCapacity: 2,
      basePrice: 12.50,
      icon: Icons.directions_car_rounded,
    ),
    VehicleOption(
      type: VehicleClass.estate,
      name: 'Estate',
      description: 'Extra luggage space for airport runs',
      capacity: 4,
      luggageCapacity: 4,
      basePrice: 15.00,
      icon: Icons.airport_shuttle_rounded,
    ),
    VehicleOption(
      type: VehicleClass.executive,
      name: 'Executive',
      description: 'Premium Mercedes/BMW with leather interior',
      capacity: 3,
      luggageCapacity: 3,
      basePrice: 22.00,
      icon: Icons.stars_rounded,
    ),
    VehicleOption(
      type: VehicleClass.mpv6,
      name: '6-Seater MPV',
      description: 'Spacious van for families & groups',
      capacity: 6,
      luggageCapacity: 5,
      basePrice: 25.00,
      icon: Icons.groups_rounded,
    ),
    VehicleOption(
      type: VehicleClass.mpv8,
      name: '8-Seater Minibus',
      description: 'Max capacity group travel with luggage',
      capacity: 8,
      luggageCapacity: 8,
      basePrice: 32.00,
      icon: Icons.directions_bus_rounded,
    ),
  ];
}

class RideQuote {
  final double fare;
  final double distanceMiles;
  final int durationMinutes;
  final String pickupPostcode;
  final String dropoffPostcode;
  final VehicleOption vehicle;

  const RideQuote({
    required this.fare,
    required this.distanceMiles,
    required this.durationMinutes,
    required this.pickupPostcode,
    required this.dropoffPostcode,
    required this.vehicle,
  });
}

class CustomerBooking {
  final String id;
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime pickupTime;
  final double fare;
  final String vehicleType;
  final String status; // 'request_sent', 'accepted', 'driver_allocated', 'arrived', 'on_trip', 'completed', 'cancelled'
  final String? driverName;
  final String? driverPhone;
  final String? vehicleReg;
  final String? vehicleModel;
  final String paymentMethod; // 'cash', 'card', 'account'
  final int passengers;
  final int luggage;

  const CustomerBooking({
    required this.id,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupTime,
    required this.fare,
    required this.vehicleType,
    required this.status,
    this.driverName,
    this.driverPhone,
    this.vehicleReg,
    this.vehicleModel,
    this.paymentMethod = 'cash',
    this.passengers = 1,
    this.luggage = 0,
  });

  CustomerBooking copyWith({
    String? status,
    String? driverName,
    String? driverPhone,
    String? vehicleReg,
    String? vehicleModel,
  }) {
    return CustomerBooking(
      id: id,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickupTime: pickupTime,
      fare: fare,
      vehicleType: vehicleType,
      status: status ?? this.status,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      vehicleReg: vehicleReg ?? this.vehicleReg,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      paymentMethod: paymentMethod,
      passengers: passengers,
      luggage: luggage,
    );
  }
}
