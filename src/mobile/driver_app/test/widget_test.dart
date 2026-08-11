import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:driver_app/main.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:driver_app/features/shift/shift.dart';

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
    );
  }

  @override
  Future<void> signIn(String username, String password) async {}

  @override
  Future<void> signOut() async {}
}

class ShiftNotifierMock extends ShiftNotifier {
  ShiftNotifierMock(super.ref);

  @override
  Future<void> goOnline() async {
    state = ShiftState(
      status: ShiftStatus.online,
      startTime: DateTime.now(),
    );
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
        ],
        child: const DriverApp(),
      ),
    );

    // Trigger initial frame
    await tester.pump();

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
