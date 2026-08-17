import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:driver_app/features/trip/trip.dart';
import 'package:driver_app/features/earnings/earnings.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/features/navigation/presentation/main_shell.dart';
import 'package:driver_app/features/shift/shift.dart';

class DriverWebviewScreen extends ConsumerStatefulWidget {
  final String url;
  final String title;
  final bool showBackButton;
  final bool hideAppBar;
  final VoidCallback? onBack;

  const DriverWebviewScreen({
    super.key,
    required this.url,
    required this.title,
    this.showBackButton = false,
    this.hideAppBar = false,
    this.onBack,
  });

  @override
  ConsumerState<DriverWebviewScreen> createState() => _DriverWebviewScreenState();
}

class _DriverWebviewScreenState extends ConsumerState<DriverWebviewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      late final PlatformWebViewControllerCreationParams params;
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      final controller = WebViewController.fromPlatformCreationParams(
        params,
        onPermissionRequest: (WebViewPermissionRequest request) async {
          debugPrint("WebView permission requested: $request");
          final status = await Permission.camera.request();
          if (status.isGranted) {
            request.grant();
          } else {
            debugPrint("WebView permission denied natively");
          }
        },
      )
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFFFFFFF))
        ..enableZoom(false)
        ..clearCache()
        ..addJavaScriptChannel(
          'FlutterChannel',
          onMessageReceived: (JavaScriptMessage message) {
            debugPrint("FlutterChannel message received: ${message.message}");
            if (message.message == 'job_accepted') {
              ref.read(tripProvider.notifier).acceptJob();
            } else if (message.message == 'job_rejected') {
              ref.read(tripProvider.notifier).rejectJob();
            } else if (message.message == 'arrived_at_pickup') {
              ref.read(tripProvider.notifier).markArrived();
            } else if (message.message == 'start_trip') {
              ref.read(tripProvider.notifier).startTrip();
            } else if (message.message == 'complete_trip') {
              ref.read(tripProvider.notifier).completeTrip();
            } else if (message.message == 'return_to_dashboard') {
              final currentTrip = ref.read(tripProvider).currentTrip;
              if (currentTrip != null) {
                ref.read(earningsProvider.notifier).addRecord(
                  EarningRecord(
                    id: currentTrip.id,
                    date: DateTime.now(),
                    amount: currentTrip.fare,
                    tripDescription: 'Pickup: ${currentTrip.pickupAddress}, Dropoff: ${currentTrip.dropoffAddress}',
                  ),
                );
              }
              ref.read(tripProvider.notifier).finishShiftItem();
            } else if (message.message == 'call_customer') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dialing passenger... (Mock)')),
              );
            } else if (message.message == 'navigate') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Launching navigation map routing... (Mock)')),
              );
            } else if (message.message == 'go_online') {
              ref.read(shiftProvider.notifier).goOnline();
            } else if (message.message == 'go_offline') {
              ref.read(shiftProvider.notifier).goOffline();
            } else if (message.message == 'simulate_cash_booking') {
              ref.read(tripProvider.notifier).offerJob(
                const TripDetails(
                  id: 'sim-cash-booking',
                  pickupAddress: 'Heathrow Airport Terminal 5',
                  dropoffAddress: 'Red Taxi Office, London Central',
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
            } else if (message.message == 'pull_refresh') {
              _controller?.reload();
            }
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint("WebView Resource Error: ${error.description}");
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
        );

      if (controller.platform is AndroidWebViewController) {
        final androidController = controller.platform as AndroidWebViewController;
        androidController.setMediaPlaybackRequiresUserGesture(false);
        androidController.setOnShowFileSelector((params) async {
          debugPrint("WebView File Selector requested: mode=${params.mode}");
          try {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.any,
              allowMultiple: params.mode == FileSelectorMode.openMultiple,
            );
            if (result != null && result.files.isNotEmpty) {
              final paths = result.files
                  .map((file) => file.path)
                  .whereType<String>()
                  .map((path) => Uri.file(path).toString())
                  .toList();
              debugPrint("WebView File Selector selected URIs: $paths");
              return paths;
            }
          } catch (e) {
            debugPrint("WebView File Selector error: $e");
          }
          return <String>[];
        });
      }

      controller.loadRequest(Uri.parse(widget.url));
      _controller = controller;
    } else {
      _isLoading = false;
    }
  }

  @override
  void didUpdateWidget(covariant DriverWebviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!kIsWeb && oldWidget.url != widget.url) {
      _controller?.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              leading: widget.showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        MainShell.scaffoldKey.currentState?.openDrawer();
                      },
                    ),
              title: Text(widget.title),
              centerTitle: false,
            ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (_controller != null && await _controller!.canGoBack()) {
            await _controller!.goBack();
            return;
          }
          final currentContext = context;
          if (widget.onBack != null) {
            widget.onBack!();
          } else if (currentContext.mounted) {
            Navigator.of(currentContext).maybePop();
          }
        },
        child: RefreshIndicator(
          color: AppTheme.primaryRed,
          backgroundColor: Colors.white,
          onRefresh: () async {
            if (_controller != null) {
              await _controller!.reload();
            }
          },
          child: kIsWeb
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.language, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Webview is not supported on Web',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please run the Flutter app on an Android Emulator, iOS Simulator, or a physical mobile device to view this screen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Container(color: Colors.white),
                    if (_controller != null) WebViewWidget(controller: _controller!),
                    if (_isLoading)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryRed,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
