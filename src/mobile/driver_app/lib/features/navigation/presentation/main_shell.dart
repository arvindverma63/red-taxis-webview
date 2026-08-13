import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver_app/core/config/constants.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/features/webview/presentation/webview_screen.dart';
import 'package:driver_app/features/dashboard/presentation/dashboard_view.dart';
import 'package:driver_app/features/trip/trip.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeNotificationHandlers();
  }

  void _initializeNotificationHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("FCM Foreground message received: ${message.data}");
      _handleNotificationPayload(message.data);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("FCM message clicked: ${message.data}");
      _handleNotificationPayload(message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("FCM initial message: ${message.data}");
        _handleNotificationPayload(message.data);
      }
    });
  }

  void _handleNotificationPayload(Map<String, dynamic> data) {
    if (data['type'] == 'NEW_JOB_OFFER') {
      final id = data['jobId'] ?? '';
      final fare = double.tryParse(data['fare'] ?? '0.0') ?? 0.0;
      final pickup = data['pickupAddress'] ?? 'Unknown Pickup';
      final dropoff = data['dropoffAddress'] ?? 'Unknown Dropoff';
      final paymentType = data['paymentType'] ?? 'Cash';
      final vehicleType = data['vehicleType'] ?? 'Standard Saloon';
      final passenger = data['passengerName'] ?? 'Passenger';
      final notes = data['notes'] ?? '';

      if (id.isNotEmpty) {
        ref.read(tripProvider.notifier).offerJob(TripDetails(
          id: id,
          pickupAddress: pickup,
          dropoffAddress: dropoff,
          fare: fare,
          paymentType: paymentType,
          vehicleType: vehicleType,
          passenger: passenger,
          notes: notes,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripProvider);
    final authState = ref.watch(authProvider);
    final token = authState.token ?? '';

    // If there is an active booking, overlay the corresponding trip screen
    if (tripState.status != TripStatus.idle && tripState.currentTrip != null) {
      final trip = tripState.currentTrip!;
      switch (tripState.status) {
        case TripStatus.offered:
          final encodedPickup = Uri.encodeComponent(trip.pickupAddress);
          final encodedDropoff = Uri.encodeComponent(trip.dropoffAddress);
          final encodedVehicle = Uri.encodeComponent(trip.vehicleType);
          final encodedPassenger = Uri.encodeComponent(trip.passenger);
          final encodedNotes = Uri.encodeComponent(trip.notes);
          return DriverWebviewScreen(
            url: '${AppConfig.webviewBaseUrl}/#/job-offer?token=$token&jobId=${trip.id}&fare=${trip.fare}&pickup=$encodedPickup&dropoff=$encodedDropoff&paymentType=${trip.paymentType}&vehicleType=$encodedVehicle&passenger=$encodedPassenger&notes=$encodedNotes',
            title: 'New Job Offer',
          );
        case TripStatus.enRouteToPickup:
        case TripStatus.arrived:
        case TripStatus.onTrip:
          final encodedPickup = Uri.encodeComponent(trip.pickupAddress);
          final encodedDropoff = Uri.encodeComponent(trip.dropoffAddress);
          final encodedVehicle = Uri.encodeComponent(trip.vehicleType);
          final encodedPassenger = Uri.encodeComponent(trip.passenger);
          final encodedNotes = Uri.encodeComponent(trip.notes);
          final statusName = tripState.status.name;
          return DriverWebviewScreen(
            url: '${AppConfig.webviewBaseUrl}/#/active-trip?token=$token&jobId=${trip.id}&fare=${trip.fare}&pickup=$encodedPickup&dropoff=$encodedDropoff&paymentType=${trip.paymentType}&vehicleType=$encodedVehicle&passenger=$encodedPassenger&notes=$encodedNotes&status=$statusName',
            title: 'Active Trip',
          );
        case TripStatus.complete:
          final encodedPickup = Uri.encodeComponent(trip.pickupAddress);
          final encodedDropoff = Uri.encodeComponent(trip.dropoffAddress);
          return DriverWebviewScreen(
            url: '${AppConfig.webviewBaseUrl}/#/trip-complete?token=$token&jobId=${trip.id}&fare=${trip.fare}&pickup=$encodedPickup&dropoff=$encodedDropoff&paymentType=${trip.paymentType}',
            title: 'Trip Complete',
          );
        default:
          break;
      }
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const DriverDashboardView(),
          DriverWebviewScreen(url: '${AppConfig.webviewBaseUrl}/?token=$token#/bookings', title: 'My Bookings'),
          DriverWebviewScreen(url: '${AppConfig.webviewBaseUrl}/?token=$token#/profile', title: 'My Profile'),
          DriverWebviewScreen(url: '${AppConfig.webviewBaseUrl}/?token=$token#/availability', title: 'Weekly Availability'),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: SafeArea(
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.grey.shade100,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                  _buildNavItem(1, Icons.calendar_month_outlined, Icons.calendar_month, 'Bookings'),
                  _buildNavItem(2, Icons.person_outline, Icons.person, 'Profile'),
                  _buildNavItem(3, Icons.event_available_outlined, Icons.event_available, 'Availability'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryRed.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? AppTheme.primaryRed : Colors.grey[600],
              size: 22,
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
