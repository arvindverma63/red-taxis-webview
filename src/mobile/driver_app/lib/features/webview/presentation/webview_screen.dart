import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:file_picker/file_picker.dart';

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
