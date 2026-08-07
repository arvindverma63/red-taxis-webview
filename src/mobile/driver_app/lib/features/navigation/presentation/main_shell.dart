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
          DriverWebviewScreen(url: AppConfig.reportsUrl, title: 'Weekly Reports'),
          DriverWebviewScreen(url: AppConfig.faqUrl, title: 'Driver Help & FAQs'),
          DriverWebviewScreen(url: AppConfig.termsUrl, title: 'Driver Terms & Agreement'),
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
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            activeIcon: Icon(Icons.help),
            label: 'FAQs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel_outlined),
            activeIcon: Icon(Icons.gavel),
            label: 'Terms',
          ),
        ],
      ),
    );
  }
}
