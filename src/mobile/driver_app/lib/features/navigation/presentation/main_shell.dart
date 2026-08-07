import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver_app/core/config/constants.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/features/dashboard/presentation/dashboard_view.dart';
import 'package:driver_app/features/webview/presentation/webview_screen.dart';
import 'package:driver_app/features/trip/trip.dart';
import 'package:driver_app/features/trip/presentation/job_offer_screen.dart';
import 'package:driver_app/features/trip/presentation/active_trip_screen.dart';
import 'package:driver_app/features/trip/presentation/trip_complete_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripProvider);

    // If there is an active booking, overlay the corresponding trip screen
    if (tripState.status != TripStatus.idle && tripState.currentTrip != null) {
      final trip = tripState.currentTrip!;
      switch (tripState.status) {
        case TripStatus.offered:
          return JobOfferScreen(trip: trip);
        case TripStatus.enRouteToPickup:
        case TripStatus.arrived:
        case TripStatus.onTrip:
          return ActiveTripScreen(trip: trip, status: tripState.status);
        case TripStatus.complete:
          return TripCompleteScreen(trip: trip);
        default:
          break;
      }
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const DriverDashboardView(),
          DriverWebviewScreen(url: AppConfig.bookingsUrl, title: 'My Bookings'),
          DriverWebviewScreen(url: AppConfig.profileUrl, title: 'My Profile'),
          DriverWebviewScreen(url: AppConfig.availabilityUrl, title: 'Weekly Availability'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryRed,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.date_range_outlined),
            activeIcon: Icon(Icons.date_range),
            label: 'Availability',
          ),
        ],
      ),
    );
  }
}
