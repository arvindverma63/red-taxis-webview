import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/widgets/widgets.dart';
import 'package:driver_app/features/trip/trip.dart';

class ActiveTripScreen extends ConsumerWidget {
  final TripDetails trip;
  final TripStatus status;

  const ActiveTripScreen({
    super.key,
    required this.trip,
    required this.status,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String stateTitle = '';
    String actionLabel = '';
    Color statusColor = AppTheme.primaryRed;
    VoidCallback? onAction;

    switch (status) {
      case TripStatus.enRouteToPickup:
        stateTitle = 'En Route to Pickup';
        actionLabel = 'Arrived at Pickup';
        statusColor = Colors.orange;
        onAction = () => ref.read(tripProvider.notifier).markArrived();
        break;
      case TripStatus.arrived:
        stateTitle = 'Arrived at Pickup';
        actionLabel = 'Start Trip';
        statusColor = Colors.blue;
        onAction = () => ref.read(tripProvider.notifier).startTrip();
        break;
      case TripStatus.onTrip:
        stateTitle = 'Passenger Onboard (On Trip)';
        actionLabel = 'Complete Trip';
        statusColor = Colors.green;
        onAction = () => ref.read(tripProvider.notifier).completeTrip();
        break;
      default:
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(stateTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling office dispatcher... (Mock)')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 44.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Active status card banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_car, color: statusColor),
                    const SizedBox(width: 12),
                    Text(
                      stateTitle.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Active Trip Details Card
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fare: £${trip.fare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        StatusBadge(
                          label: trip.paymentType,
                          color: trip.paymentType.toLowerCase() == 'cash' 
                              ? Colors.green 
                              : Colors.blue,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    // Show directions indicators
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.my_location, color: Colors.blue, size: 20),
                            Container(width: 2, height: 40, color: Colors.grey[350]),
                            const Icon(Icons.location_on, color: AppTheme.primaryRed, size: 20),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PICKUP', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(trip.pickupAddress, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 24),
                              const Text('DROP-OFF', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(trip.dropoffAddress, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tactical utilities card (Navigate, Call)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.phone_outlined),
                      label: const Text('Call Customer'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Dialing passenger... (Mock)')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('Navigate'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Launching navigation map routing... (Mock)')),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Main Transition trigger action button
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
