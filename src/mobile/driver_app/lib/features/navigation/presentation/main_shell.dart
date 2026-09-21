import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:driver_app/core/config/constants.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/notifications/notification_handler.dart';
import 'package:driver_app/features/navigation/presentation/navigation_notifier.dart';
import 'package:driver_app/features/webview/presentation/webview_screen.dart';
import 'package:driver_app/features/dashboard/presentation/dashboard_view.dart';
import 'package:driver_app/features/trip/trip.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:driver_app/features/settings/presentation/settings_view.dart';
import 'package:driver_app/core/widgets/widgets.dart';
import 'package:flutter/services.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationNavigationHandler.registerRef(ref);
    });
  }

  @override
  void dispose() {
    NotificationNavigationHandler.unregisterRef();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripProvider);
    final authState = ref.watch(authProvider);
    final navState = ref.watch(navigationProvider);
    final branding = authState.tenantBranding ?? TenantBranding.defaultRedTaxis();
    final token = authState.token ?? '';
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final themeStr = isDark ? 'dark' : 'light';
    final fontScale = ref.watch(fontSizeScaleProvider).scale;

    // If there is an active booking, overlay the corresponding trip screen
    if (tripState.status == TripStatus.offered && tripState.currentTrip != null) {
      final trip = tripState.currentTrip!;
      final encodedPickup = Uri.encodeComponent(trip.pickupAddress);
      final encodedDropoff = Uri.encodeComponent(trip.dropoffAddress);
      final encodedVehicle = Uri.encodeComponent(trip.vehicleType);
      final encodedPassenger = Uri.encodeComponent(trip.passenger);
      final encodedNotes = Uri.encodeComponent(trip.notes);
      final encodedGuid = Uri.encodeComponent(trip.guid);
      final encodedVias = Uri.encodeComponent(jsonEncode(trip.vias));
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            ref.read(tripProvider.notifier).rejectJob();
          }
        },
        child: DriverWebviewScreen(
          url: '${AppConfig.webviewBaseUrl}/?token=$token&theme=$themeStr&fontScale=$fontScale#/job-offer?jobId=${trip.id}&guid=$encodedGuid&fare=${trip.fare}&pickup=$encodedPickup&dropoff=$encodedDropoff&paymentType=${trip.paymentType}&vehicleType=$encodedVehicle&passenger=$encodedPassenger&notes=$encodedNotes&vias=$encodedVias',
          title: 'New Job Offer',
          hideAppBar: true,
          onBack: () {
            ref.read(tripProvider.notifier).rejectJob();
          },
        ),
      );
    }

    // If a custom webview route is triggered (e.g. via notification nav_id: "upload" or custom URL)
    if (navState.hasCustomRoute) {
      final customRoute = navState.customRoute!;
      var prefix = customRoute.startsWith('/') ? customRoute : '/$customRoute';
      
      if (navState.customParams != null && navState.customParams!.isNotEmpty) {
        final queryParts = <String>[];
        navState.customParams!.forEach((key, value) {
          queryParts.add('$key=${Uri.encodeComponent(value)}');
        });
        final queryStr = queryParts.join('&');
        if (prefix.contains('?')) {
          prefix = '$prefix&$queryStr';
        } else {
          prefix = '$prefix?$queryStr';
        }
      }

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            final customCtrl = WebviewRegistry.customController;
            if (customCtrl != null && await customCtrl.canGoBack()) {
              await customCtrl.goBack();
              return;
            }
            ref.read(navigationProvider.notifier).closeCustomWebView();
          }
        },
        child: DriverWebviewScreen(
          isCustomRoute: true,
          url: '${AppConfig.webviewBaseUrl}/?token=$token&theme=$themeStr&fontScale=$fontScale#$prefix',
          title: navState.customTitle ?? 'Details',
          showBackButton: true,
          onBack: () async {
            final customCtrl = WebviewRegistry.customController;
            if (customCtrl != null && await customCtrl.canGoBack()) {
              await customCtrl.goBack();
            } else {
              ref.read(navigationProvider.notifier).closeCustomWebView();
            }
          },
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If Drawer is open, close it
        if (MainShell.scaffoldKey.currentState?.isDrawerOpen ?? false) {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
          return;
        }

        // 2. If Custom WebView route is open, close it
        if (navState.hasCustomRoute) {
          final customCtrl = WebviewRegistry.customController;
          if (customCtrl != null && await customCtrl.canGoBack()) {
            await customCtrl.goBack();
            return;
          }
          ref.read(navigationProvider.notifier).closeCustomWebView();
          return;
        }

        // 3. Check if active tab's WebView has history to go back
        final activeController = WebviewRegistry.tabControllers[navState.selectedIndex];
        if (activeController != null && await activeController.canGoBack()) {
          await activeController.goBack();
          return;
        }

        // 4. If on a sub-tab (Bookings, Profile, Availability, Expenses, etc.), go back to Dashboard
        if (navState.selectedIndex != 0) {
          ref.read(navigationProvider.notifier).setTabIndex(0);
          return;
        }

        // 5. On Dashboard with no webview history, require double-back-to-exit within 2 seconds
        final now = DateTime.now();
        final branding = authState.tenantBranding ?? TenantBranding.defaultRedTaxis();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Press back again to exit ${branding.name}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: MainShell.scaffoldKey,
        drawer: _buildDrawer(context, navState.selectedIndex),
        body: IndexedStack(
          index: navState.selectedIndex,
          children: [
            const DriverDashboardView(),
            DriverWebviewScreen(tabIndex: 1, url: '${AppConfig.webviewBaseUrl}/?token=$token&theme=$themeStr&fontScale=$fontScale#/bookings', title: 'My Bookings'),
            DriverWebviewScreen(tabIndex: 2, url: '${AppConfig.webviewBaseUrl}/?token=$token&theme=$themeStr&fontScale=$fontScale#/profile', title: 'My Profile'),
            DriverWebviewScreen(tabIndex: 3, url: '${AppConfig.webviewBaseUrl}/?token=$token&theme=$themeStr&fontScale=$fontScale#/availability', title: 'Weekly Availability'),
            DriverWebviewScreen(tabIndex: 4, url: '${AppConfig.webviewBaseUrl}/?token=$token&theme=$themeStr&fontScale=$fontScale#/expenses', title: 'Expenses Log'),
            DriverWebviewScreen(tabIndex: 5, url: '${AppConfig.webviewBaseUrl}/?token=$token&theme=$themeStr&fontScale=$fontScale#/create-booking', title: 'Rank Pickup'),
            DriverWebviewScreen(tabIndex: 6, url: '${AppConfig.webviewBaseUrl}/?token=$token&theme=$themeStr&fontScale=$fontScale#/reports', title: 'Reports & Statements'),
            const SettingsView(),
          ],
        ),
        bottomNavigationBar: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SafeArea(
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: branding.primaryColor.withValues(alpha: isDark ? 0.10 : 0.05),
                    blurRadius: 16,
                    spreadRadius: -2,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Dashboard', navState.selectedIndex, branding.primaryColor),
                    _buildNavItem(1, Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Bookings', navState.selectedIndex, branding.primaryColor),
                    _buildNavItem(2, Icons.person_outline_rounded, Icons.person_rounded, 'Profile', navState.selectedIndex, branding.primaryColor),
                    _buildNavItem(3, Icons.schedule_outlined, Icons.schedule_rounded, 'Availability', navState.selectedIndex, branding.primaryColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData inactiveIcon,
    IconData activeIcon,
    String label,
    int activeIndex,
    Color primaryColor,
  ) {
    final isActive = activeIndex == index;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(navigationProvider.notifier).setTabIndex(index);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 6 : 2,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor.withValues(alpha: isDark ? 0.22 : 0.12),
                      primaryColor.withValues(alpha: isDark ? 0.10 : 0.05),
                    ],
                  )
                : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isActive
                ? Border.all(
                    color: primaryColor.withValues(alpha: isDark ? 0.40 : 0.22),
                    width: 1.2,
                  )
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: isDark ? 0.18 : 0.08),
                      blurRadius: 8,
                      spreadRadius: -1,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isActive ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(
                  isActive ? activeIcon : inactiveIcon,
                  color: isActive
                      ? primaryColor
                      : (isDark ? const Color(0xFF90A4AE) : const Color(0xFF64748B)),
                  size: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? (isDark ? Colors.white : primaryColor)
                      : (isDark ? const Color(0xFF78909C) : const Color(0xFF64748B)),
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, int activeIndex) {
    final authState = ref.watch(authProvider);
    final branding = authState.tenantBranding ?? TenantBranding.defaultRedTaxis();
    final email = authState.email ?? 'Partner Driver';
    final name = email.contains('@') ? email.split('@')[0] : email;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Drawer(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Custom Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [branding.gradientStart, branding.gradientMid],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
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
                          padding: const EdgeInsets.all(6),
                          child: Center(
                            child: BrandedLogo(
                              branding: branding,
                              size: 52,
                              shape: BoxShape.circle,
                              fit: BoxFit.contain,
                              customFallback: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'D',
                                  style: TextStyle(
                                    fontSize: 26.0,
                                    fontWeight: FontWeight.w900,
                                    color: branding.primaryColor,
                                  ),
                                ),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${branding.name} Driver',
                                style: const TextStyle(
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
                        _buildDrawerItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', activeIndex),
                        _buildDrawerItem(1, Icons.calendar_month_outlined, Icons.calendar_month, 'My Bookings', activeIndex),
                        _buildDrawerItem(2, Icons.person_outline, Icons.person, 'My Profile', activeIndex),
                        _buildDrawerItem(3, Icons.event_available_outlined, Icons.event_available, 'Weekly Availability', activeIndex),
                        _buildDrawerItem(4, Icons.receipt_long_outlined, Icons.receipt_long, 'My Expenses', activeIndex),
                        _buildDrawerItem(5, Icons.add_circle_outline, Icons.add_circle, 'Rank Pickup', activeIndex),
                        _buildDrawerItem(6, Icons.bar_chart_outlined, Icons.bar_chart, 'Reports & Statements', activeIndex),
                        _buildDrawerItem(7, Icons.settings_outlined, Icons.settings, 'Settings', activeIndex),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Sign Out Button Card at bottom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
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
              '${branding.name.toUpperCase()} PARTNER v1.0.0',
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

  Widget _buildDrawerItem(int index, IconData inactiveIcon, IconData activeIcon, String title, int activeIndex) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final isActive = activeIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: ListTile(
        leading: Icon(
          isActive ? activeIcon : inactiveIcon,
          color: isActive ? AppTheme.primaryRed : (isDark ? AppTheme.textDarkSecondary : Colors.grey.shade600),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? AppTheme.primaryRed : (isDark ? AppTheme.textDarkPrimary : Colors.grey.shade800),
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        selected: isActive,
        selectedTileColor: AppTheme.primaryRed.withValues(alpha: isDark ? 0.15 : 0.08),
        onTap: () {
          ref.read(navigationProvider.notifier).setTabIndex(index);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
