import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:driver_app/features/settings/presentation/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth extends AuthNotifier {
  _FakeAuth(this.initial, this.result);

  final AuthState initial;
  final BrandingSyncResult result;
  int syncCalls = 0;

  @override
  Future<BrandingSyncResult> syncTenantBranding() async {
    syncCalls++;
    return result;
  }
}

void main() {
  final branding = TenantBranding.fromJson({
    'tenantId': 'org_x',
    'companyName': 'Insta-Taxi',
    'primaryHsl': '200 98% 39%',
    'secondaryHsl': '27 31% 94%',
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<_FakeAuth> pump(WidgetTester tester, BrandingSyncResult result) async {
    // The test font (Ahem) is much wider than real text, so unrelated rows
    // overflow here; layout overflow is not what these tests check.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final fake = _FakeAuth(
      AuthState(
        status: AuthStatus.authenticated,
        email: 'driver@example.com',
        tenantId: 'org_x',
        tenantKey: 'k',
        tenantBranding: branding,
        isTenantConfigured: true,
      ),
      result,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith((ref) => fake)],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.getDynamicLightTheme(branding),
            home: const SettingsView(),
          ),
        ),
      ),
    );
    // Let the notifier's own start-up (secure storage) finish, then put the
    // configured state back.
    await tester.pump(const Duration(milliseconds: 300));
    fake.state = fake.initial;
    await tester.pump(const Duration(milliseconds: 300));
    return fake;
  }

  testWidgets('Settings shows the fleet theme card with a Sync button', (tester) async {
    await pump(tester, BrandingSyncResult.updated);
    expect(find.text('FLEET THEME'), findsOneWidget);
    expect(find.text('Fleet theme'), findsOneWidget);
    expect(find.text('Sync theme now'), findsOneWidget);
    expect(find.text('Not synced yet'), findsOneWidget);
  });

  testWidgets('tapping Sync calls the notifier and reports the result', (tester) async {
    final fake = await pump(tester, BrandingSyncResult.updated);
    await tester.ensureVisible(find.text('Sync theme now'));
    await tester.tap(find.text('Sync theme now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.syncCalls, 1);
    expect(find.text('Theme updated from your fleet.'), findsOneWidget);
  });

  testWidgets('a failed sync says the current theme was kept', (tester) async {
    await pump(tester, BrandingSyncResult.failed);
    await tester.ensureVisible(find.text('Sync theme now'));
    await tester.tap(find.text('Sync theme now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Could not reach the server. Your current theme was kept.'),
      findsOneWidget,
    );
  });
}
