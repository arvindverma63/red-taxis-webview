import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DriverWebviewScreen extends StatefulWidget {
  final String url;
  final String title;

  const DriverWebviewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<DriverWebviewScreen> createState() => _DriverWebviewScreenState();
}

class _DriverWebviewScreenState extends State<DriverWebviewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      final controller = WebViewController.fromPlatformCreationParams(
        const PlatformWebViewControllerCreationParams(),
        onPermissionRequest: (WebViewPermissionRequest request) {
          debugPrint("WebView permission requested: $request");
          request.grant();
        },
      )
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..enableZoom(false)
        ..clearCache()
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
          ),
        )
        ..loadRequest(Uri.parse(widget.url));

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
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller?.reload(),
            ),
        ],
      ),
      body: kIsWeb
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
                WebViewWidget(controller: _controller!),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
    );
  }
}
