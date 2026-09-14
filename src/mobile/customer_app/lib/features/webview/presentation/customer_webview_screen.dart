import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../../core/config/constants.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/branded_logo.dart';
import '../../../core/widgets/offline_error_widget.dart';
import '../../auth/application/auth_notifier.dart';

class CustomerWebviewScreen extends ConsumerStatefulWidget {
  final String subRoute;
  final String title;
  final bool showBackButton;
  final bool hideAppBar;
  final VoidCallback? onBack;

  const CustomerWebviewScreen({
    super.key,
    required this.subRoute,
    required this.title,
    this.showBackButton = false,
    this.hideAppBar = false,
    this.onBack,
  });

  @override
  ConsumerState<CustomerWebviewScreen> createState() => _CustomerWebviewScreenState();
}

class _CustomerWebviewScreenState extends ConsumerState<CustomerWebviewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;

  String _buildFullUrl() {
    final auth = ref.read(authProvider);
    final branding = ref.read(tenantBrandingProvider);
    final themeMode = ref.read(themeModeProvider);

    final token = auth.token ?? '';
    final themeParam = themeMode == ThemeMode.dark ? 'dark' : 'light';
    final tenantId = branding.tenantId;

    const baseUrl = AppConfig.webviewBaseUrl;
    final sub = widget.subRoute;

    final delimiter = sub.contains('?') ? '&' : '?';
    return '$baseUrl$sub${delimiter}token=$token&theme=$themeParam&tenantId=$tenantId';
  }

  void _reloadWebView() {
    if (_controller != null) {
      setState(() {
        _hasError = false;
        _isLoading = true;
      });
      _controller!.loadRequest(Uri.parse(_buildFullUrl()));
    }
  }

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    if (kIsWeb) return;

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final isDark = ref.read(themeModeProvider) == ThemeMode.dark;

    final controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (WebViewPermissionRequest request) async {
        final status = await Permission.camera.request();
        if (status.isGranted) {
          request.grant();
        }
      },
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF))
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final msg = message.message;
          debugPrint('Customer FlutterChannel message: $msg');
          if (msg == 'scan_qr') {
            context.push('/auth/qr-scan');
          } else if (msg == 'open_saved_places') {
            context.push('/saved-places');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Customer WebView error: ${error.errorCode} - ${error.description}');
            if (error.isForMainFrame ?? true) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url.toLowerCase();
            if (url.startsWith('tel:') ||
                url.startsWith('sms:') ||
                url.startsWith('geo:') ||
                url.startsWith('intent:') ||
                url.contains('maps.google.com') ||
                url.contains('goo.gl/maps')) {
              try {
                final uri = Uri.parse(request.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (_) {}
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    controller.loadRequest(Uri.parse(_buildFullUrl()));
    _controller = controller;
  }

  @override
  void didUpdateWidget(covariant CustomerWebviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subRoute != widget.subRoute) {
      _controller?.loadRequest(Uri.parse(_buildFullUrl()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = ref.watch(tenantBrandingProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Web platform fallback banner
    if (kIsWeb) {
      return Scaffold(
        appBar: widget.hideAppBar
            ? null
            : AppBar(
                title: Text(widget.title),
                leading: widget.showBackButton
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
                      )
                    : null,
              ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BrandedLogo(branding: branding, size: 50, isDark: isDark),
              const SizedBox(height: 16),
              Text(
                '${widget.title} (Webview Host)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Webviews run natively on iOS & Android build targets.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 16),
              Text(
                'Target URL: ${_buildFullUrl()}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blueGrey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (_controller != null && await _controller!.canGoBack()) {
          await _controller!.goBack();
          return;
        }
        if (widget.onBack != null) {
          widget.onBack!();
        } else if (mounted) {
          navigator.maybePop();
        }
      },
      child: Scaffold(
        appBar: widget.hideAppBar
            ? null
            : AppBar(
                title: Row(
                  children: [
                    BrandedLogo(branding: branding, size: 28, isDark: isDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                leading: widget.showBackButton
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
                      )
                    : null,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh Page',
                    onPressed: _reloadWebView,
                  ),
                ],
              ),
        body: SafeArea(
          child: Stack(
            children: [
              if (_hasError)
                OfflineErrorWidget(
                  onRetry: _reloadWebView,
                  title: 'Unable to Load Page',
                  message: 'Please verify your internet connection or server availability.',
                )
              else if (_controller != null)
                RefreshIndicator(
                  color: branding.primaryColor,
                  onRefresh: () async {
                    _reloadWebView();
                  },
                  child: WebViewWidget(controller: _controller!),
                ),
              if (_isLoading && !_hasError)
                Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: branding.primaryColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
