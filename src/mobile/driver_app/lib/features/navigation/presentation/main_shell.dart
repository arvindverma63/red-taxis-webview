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

  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

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
      key: MainShell.scaffoldKey,
      drawer: _buildDrawer(context),
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

  Widget _buildDrawer(BuildContext context) {
    final authState = ref.watch(authProvider);
    final email = authState.email ?? 'Partner Driver';
    final name = email.contains('@') ? email.split('@')[0] : email;

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryRed, AppTheme.primaryDarkRed],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: const TextStyle(
                        fontSize: 26.0,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryRed,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                // Verified Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Verified Driver',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Drawer tab list options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildDrawerItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                _buildDrawerItem(1, Icons.calendar_month_outlined, Icons.calendar_month, 'My Bookings'),
                _buildDrawerItem(2, Icons.person_outline, Icons.person, 'My Profile'),
                _buildDrawerItem(3, Icons.event_available_outlined, Icons.event_available, 'Weekly Availability'),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Sign Out Button Card at bottom
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_outlined, size: 18),
              label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade100, width: 1.5),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: Colors.red.shade50.withValues(alpha: 0.3),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).signOut();
              },
            ),
          ),
          
          // Tiny Brand Footer
          Center(
            child: Text(
              'RED TAXIS PARTNER v1.0.0',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, IconData inactiveIcon, IconData activeIcon, String title) {
    final isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: ListTile(
        leading: Icon(
          isActive ? activeIcon : inactiveIcon,
          color: isActive ? AppTheme.primaryRed : Colors.grey[700],
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? AppTheme.primaryRed : Colors.grey[800],
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        selected: isActive,
        selectedTileColor: AppTheme.primaryRed.withValues(alpha: 0.08),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
