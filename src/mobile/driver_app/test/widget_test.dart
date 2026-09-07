import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:driver_app/main.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:driver_app/features/shift/shift.dart';
import 'package:driver_app/features/trip/trip.dart';
import 'package:driver_app/core/location/location.dart';

class MockWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return MockPlatformWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return MockPlatformWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return MockPlatformNavigationDelegate(params);
  }
}

class MockPlatformNavigationDelegate extends PlatformNavigationDelegate {
  MockPlatformNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnPageStarted(void Function(String url) onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(void Function(String url) onPageFinished) async {}

  @override
  Future<void> setOnWebResourceError(void Function(WebResourceError error) onWebResourceError) async {}

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}
}

class MockPlatformWebViewController extends PlatformWebViewController {
  MockPlatformWebViewController(super.params) : super.implementation();

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
  
  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}

  @override
  Future<void> enableZoom(bool enabled) async {}

  @override
  Future<void> clearCache() async {}

  @override
  Future<void> reload() async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setOnPlatformPermissionRequest(
    void Function(PlatformWebViewPermissionRequest request) onPermissionRequest,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams javaScriptChannelParams) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {}
}

class MockPlatformWebViewWidget extends PlatformWebViewWidget {
  MockPlatformWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class AuthNotifierMock extends AuthNotifier {
  AuthNotifierMock() : super() {
    state = const AuthState(
      status: AuthStatus.authenticated,
      email: 'peter.parker@redtaxis.com',
      token: 'mock-token',
      userId: 65,
      isTenantConfigured: true,
    );
  }

  @override
  Future<void> signIn(String username, String password) async {}

  @override
  Future<void> signOut() async {}
}

class TripNotifierMock extends TripNotifier {
  TripNotifierMock(super.ref);

  @override
  Future<void> checkActiveJob() async {}
}

class ShiftNotifierMock extends ShiftNotifier {
  ShiftNotifierMock(super.ref);

  @override
  Future<LocationPermissionResult> goOnline() async {
    state = ShiftState(
      status: ShiftStatus.online,
      startTime: DateTime.now(),
    );
    return LocationPermissionResult.granted;
  }

  @override
  Future<void> goOffline() async {
    state = const ShiftState(status: ShiftStatus.offline);
  }
}

void main() {
  setUpAll(() {
    WebViewPlatform.instance = MockWebViewPlatform();
  });

  testWidgets('Driver Dashboard Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifierMock()),
          shiftProvider.overrideWith((ref) => ShiftNotifierMock(ref)),
          tripProvider.overrideWith((ref) => TripNotifierMock(ref)),
        ],
        child: const DriverApp(),
      ),
    );

    // Advance past splash screen into dashboard
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that the dashboard starts in OFFLINE mode.
    expect(find.text('Off Duty'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);

    // Tap the 'Go Online' button.
    await tester.tap(find.text('Go Online'));
    await tester.pump();

    // Verify that it changes status to ONLINE.
    expect(find.text('On Duty'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);
  });
}
