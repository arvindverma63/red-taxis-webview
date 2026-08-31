import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:driver_app/core/config/constants.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/widgets/widgets.dart';
import 'package:driver_app/features/shift/shift.dart';
import 'package:driver_app/features/trip/trip.dart';
import 'package:driver_app/core/location/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:driver_app/features/navigation/presentation/main_shell.dart';
import 'package:driver_app/features/navigation/presentation/navigation_notifier.dart';

class DriverDashboardView extends ConsumerStatefulWidget {
  const DriverDashboardView({super.key});

  @override
  ConsumerState<DriverDashboardView> createState() => _DriverDashboardViewState();
}

class _DriverDashboardViewState extends ConsumerState<DriverDashboardView> {
  WebViewController? _controller;
  bool _isLoading = true;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _initWebViewController() {
    final token = ref.read(authProvider).token ?? '';
    final shift = ref.read(shiftProvider);
    final url = '${AppConfig.webviewBaseUrl}/?token=$token&shiftStatus=${shift.status.name}#/dashboard';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("Dashboard WebView Error: ${error.description}");
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            final uri = Uri.tryParse(url);
            if (uri == null) return NavigationDecision.prevent;

            final scheme = uri.scheme.toLowerCase();
            if (scheme == 'tel' ||
                scheme == 'sms' ||
                scheme == 'mailto' ||
                scheme == 'geo' ||
                scheme == 'intent' ||
                url.contains('maps.google.com') ||
                url.contains('www.google.com/maps') ||
                url.contains('maps.apple.com')) {
              try {
                if (scheme == 'intent') {
                  String parsedUrl = url;
                  if (url.startsWith('intent://')) {
                    final stripped = url.substring('intent://'.length);
                    final intentIndex = stripped.indexOf('#Intent');
                    final cleanHostPath = intentIndex != -1 ? stripped.substring(0, intentIndex) : stripped;
                    parsedUrl = 'https://$cleanHostPath';
                  }
                  final intentUri = Uri.parse(parsedUrl);
                  if (await canLaunchUrl(intentUri)) {
                    await launchUrl(intentUri, mode: LaunchMode.externalApplication);
                  }
                } else {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              } catch (e) {
                debugPrint("Error launching external url $url: $e");
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint("Dashboard WebView message received: ${message.message}");
          if (message.message == 'simulate_cash_booking') {
            ref.read(tripProvider.notifier).offerJob(
              const TripDetails(
                id: 'sim-cash-booking',
                pickupAddress: 'Heathrow Airport Terminal 5',
                dropoffAddress: 'First Taxis Office, London Central',
                fare: 45.00,
                paymentType: 'Cash',
              ),
            );
          } else if (message.message == 'simulate_card_booking') {
            ref.read(tripProvider.notifier).offerJob(
              const TripDetails(
                id: 'sim-card-booking',
                pickupAddress: 'Wembley Stadium Gate A',
                dropoffAddress: 'Hilton London Metropole',
                fare: 28.50,
                paymentType: 'Card',
              ),
            );
          } else if (message.message == 'go_online') {
            ref.read(shiftProvider.notifier).goOnline();
          } else if (message.message == 'go_offline') {
            ref.read(shiftProvider.notifier).goOffline();
          } else if (message.message == 'pull_refresh') {
            _controller?.reload();
          } else if (message.message.startsWith('open_complete_job:')) {
            final parts = message.message.split(':');
            if (parts.length >= 3) {
              final jobId = parts[1];
              final fare = parts[2];
              ref.read(navigationProvider.notifier).openCustomWebView(
                route: '/complete-job',
                title: 'Complete Job',
                params: {
                  'jobId': jobId,
                  'fare': fare,
                },
              );
            }
          } else if (message.message == 'close_complete_job') {
            ref.read(navigationProvider.notifier).closeCustomWebView();
          }
        },
      );

    controller.loadRequest(Uri.parse(url));
    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    final shift = ref.watch(shiftProvider);
    final isOnline = shift.status == ShiftStatus.online;

    // Listen for shift changes to keep the WebView URL synchronized reactively
    ref.listen(shiftProvider, (previous, next) {
      if (previous?.status != next.status) {
        try {
          final token = ref.read(authProvider).token ?? '';
          final url = '${AppConfig.webviewBaseUrl}/?token=$token&shiftStatus=${next.status.name}#/dashboard';
          _controller?.loadRequest(Uri.parse(url));
        } catch (e) {
          debugPrint("[Dashboard] WebView shift change reload error: $e");
        }
      }
    });

    // Listen for authentication changes (like auto-login resolving or login success)
    // to reload the WebView with the valid token
    ref.listen(authProvider, (previous, next) {
      if (previous?.token != next.token) {
        try {
          final token = next.token ?? '';
          final shift = ref.read(shiftProvider);
          final url = '${AppConfig.webviewBaseUrl}/?token=$token&shiftStatus=${shift.status.name}#/dashboard';
          _controller?.loadRequest(Uri.parse(url));
        } catch (e) {
          debugPrint("[Dashboard] WebView auth change reload error: $e");
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            MainShell.scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const Text('First Taxis Dashboard'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications feature coming soon.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign Out',
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryRed,
        backgroundColor: Colors.white,
        onRefresh: () async {
          if (_controller != null) {
            await _controller!.reload();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Native Shift Status Toggle Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: CustomCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                                boxShadow: isOnline
                                    ? [
                                        BoxShadow(
                                          color: Colors.green.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOnline ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                color: isOnline ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          isOnline ? 'On Duty' : 'Off Duty',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isOnline
                          ? 'You are active on the network and waiting to accept incoming ride offers. Live GPS tracking is active.'
                          : 'Go online to start receiving booking requests in your area.',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOnline ? Colors.grey[850] : AppTheme.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                        disabledBackgroundColor: isOnline ? Colors.grey[800]?.withOpacity(0.6) : AppTheme.primaryRed.withOpacity(0.6),
                        disabledForegroundColor: Colors.white70,
                      ),
                      onPressed: shift.isLoading
                          ? null
                          : () async {
                              if (isOnline) {
                                ref.read(shiftProvider.notifier).goOffline();
                              } else {
                                final result = await ref.read(shiftProvider.notifier).goOnline();
                                if (result != LocationPermissionResult.granted && context.mounted) {
                                  _showLocationSettingsDialog(context, result);
                                }
                              }
                            },
                      child: shift.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isOnline ? Icons.power_settings_new : Icons.play_arrow,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(isOnline ? 'Go Offline' : 'Go Online'),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // Thin Loading bar for WebView loading state
            if (_isLoading)
              const SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  color: AppTheme.primaryRed,
                  backgroundColor: Colors.transparent,
                ),
              ),

            // 2. Hybrid Data WebView (displays Today's summary and Recent completed trips list)
            Expanded(
              child: _controller != null
                  ? WebViewWidget(controller: _controller!)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationSettingsDialog(BuildContext context, LocationPermissionResult result) {
    String title;
    String message;
    bool isServiceDisabled = result == LocationPermissionResult.serviceDisabled;

    if (isServiceDisabled) {
      title = 'Location Services Disabled';
      message = 'GPS location services are disabled on your device. Please enable location services to go online.';
    } else {
      title = 'Location Permission Required';
      message = 'First Taxis requires precise background location permissions to receive booking offers. Please grant permission in settings.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, popResult) {
            if (didPop) {
              _locationTimer?.cancel();
            }
          },
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.location_off, color: AppTheme.primaryRed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  _locationTimer?.cancel();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  if (isServiceDisabled) {
                    Geolocator.openLocationSettings();
                  } else {
                    Geolocator.openAppSettings();
                  }

                  // 2-second periodic check loop to auto-verify settings changes
                  _locationTimer?.cancel();
                  _locationTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
                    final locService = LocationService();
                    final checkResult = await locService.checkPermissions();
                    if (checkResult == LocationPermissionResult.granted) {
                      timer.cancel();
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(); // Auto-dismiss dialog
                      }
                      ref.read(shiftProvider.notifier).goOnline(); // Auto-go online
                    }
                  });
                },
                child: Text(isServiceDisabled ? 'Open Settings' : 'App Settings'),
              ),
            ],
          ),
        );
      },
    );
  }
}
