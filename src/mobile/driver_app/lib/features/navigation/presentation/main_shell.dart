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
