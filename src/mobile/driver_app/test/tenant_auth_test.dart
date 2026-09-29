import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/widgets/widgets.dart';
import 'package:driver_app/core/location/location.dart';
import 'package:driver_app/features/auth/auth.dart';

void main() {
  group('Multi-Tenant Configuration & Branding Tests', () {
    test('Default Red Taxis branding generates correct colors and tenantId', () {
      final branding = TenantBranding.defaultRedTaxis();
      expect(branding.tenantId, 'org_red_taxis');
      expect(branding.name, 'Red Taxis');
      expect(branding.primaryHex, '#D32F2F');
    });

    test('Default First Taxis branding generates correct colors and tenantId', () {
      final branding = TenantBranding.defaultFirstTaxis();
      expect(branding.tenantId, 'org_first_taxis');
      expect(branding.name, 'First Taxis');
      expect(branding.primaryHex, '#CD1A21');
    });

    test('Default Ace Taxis branding generates correct colors and tenantId', () {
      final branding = TenantBranding.defaultAceTaxis();
      expect(branding.tenantId, 'org_ace_taxis');
      expect(branding.name, 'Ace Taxis');
      expect(branding.primaryHex, '#E53935');
    });

    test('TenantBranding JSON serialization and deserialization roundtrip', () {
      final original = TenantBranding.defaultFirstTaxis();
      final json = original.toJson();
      final restored = TenantBranding.fromJson(json);

      expect(restored.tenantId, original.tenantId);
      expect(restored.name, original.name);
      expect(restored.primaryHex, original.primaryHex);
      expect(restored.dispatchPhone, original.dispatchPhone);
    });

    test('AuthState defaults to unconfigured when no tenant is set', () {
      const state = AuthState(status: AuthStatus.unauthenticated);
      expect(state.isTenantConfigured, false);
      expect(state.tenantId, isNull);
    });

    test('AuthState transitions to configured with tenant details', () {
      final branding = TenantBranding.defaultFirstTaxis();
      final state = AuthState(
        status: AuthStatus.unauthenticated,
        tenantId: 'org_first_taxis',
        tenantKey: 'tk_live_8f93c72b10a94e82b7',
        tenantBranding: branding,
        isTenantConfigured: true,
      );

      expect(state.isTenantConfigured, true);
      expect(state.tenantId, 'org_first_taxis');
      expect(state.tenantBranding?.name, 'First Taxis');
    });

    test('TenantBranding correctly parses /api/v2/public/tenant-info payload', () {
      final apiResponse = {
        "success": true,
        "data": {
          "tenantId": "org_08f19f20899e43308c1c1db3",
          "companyName": "instacreator",
          "phone": "7777777777",
          "email": "officialadarsh2023@gmail.com",
          "website": "",
          "logoUrl": "",
          "primaryColour": "#6366F1",
          "address": {
            "line1": "",
            "line2": "",
            "line3": "",
            "line4": "",
            "postcode": "208013"
          }
        },
        "errors": []
      };

      final branding = TenantBranding.fromJson(apiResponse);
      expect(branding.tenantId, 'org_08f19f20899e43308c1c1db3');
      expect(branding.name, 'instacreator');
      expect(branding.dispatchPhone, '7777777777');
      expect(branding.supportEmail, 'officialadarsh2023@gmail.com');
      expect(branding.primaryHex, '#6366F1');
    });

    testWidgets('BrandedLogo renders cleanly with fallback icon when logo URL is empty', (tester) async {
      final branding = TenantBranding.defaultRedTaxis();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandedLogo(
              branding: branding,
              size: 48,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BrandedLogo), findsOneWidget);
    });

    test('FontSizeOption scale parsing and descriptions', () {
      expect(FontSizeOption.fromScale(1.0), FontSizeOption.standard);
      expect(FontSizeOption.fromScale(1.15), FontSizeOption.large);
      expect(FontSizeOption.fromScale(1.30), FontSizeOption.extraLarge);
      expect(FontSizeOption.standard.scale, 1.0);
      expect(FontSizeOption.large.scale, 1.15);
      expect(FontSizeOption.extraLarge.scale, 1.30);
    });

    testWidgets('LocationDisclosureDialog displays required Google Play background disclosure wording', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LocationDisclosureDialog(
              fleetName: 'Red Taxis',
              isReadOnly: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Background Location Access'), findsOneWidget);
      expect(find.text('Prominent Disclosure & Consent'), findsOneWidget);
      expect(find.textContaining('even when the app is closed or not in use', findRichText: true), findsOneWidget);
      expect(find.text('Agree & Enable Location'), findsOneWidget);
      expect(find.text('Deny & Stay Offline'), findsOneWidget);
    });

    testWidgets('LocationDisclosureDialog displays in read-only mode with Close button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LocationDisclosureDialog(
              fleetName: 'First Taxis',
              isReadOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Close'), findsOneWidget);
      expect(find.textContaining('First Taxis collects location data', findRichText: true), findsOneWidget);
    });

    testWidgets('PrivacyPolicyDialog renders Privacy Policy and Terms tabs with fleet branding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrivacyPolicyDialog(
              fleetName: 'Red Taxis',
              initialTabIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Red Taxis Legal'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Your Privacy Is Protected'), findsOneWidget);
      expect(find.text('Information We Collect'), findsOneWidget);
      expect(find.text('I Understand'), findsOneWidget);
      expect(find.text('Web Version'), findsOneWidget);

      // Switch to Terms of Service tab
      await tester.tap(find.text('Terms of Service'));
      await tester.pumpAndSettle();

      expect(find.text('Driver Terms of Service'), findsOneWidget);
      expect(find.text('Driver Eligibility & Compliance'), findsOneWidget);
    });

    test('PrivacyPolicyDialog has correct staging-saas URLs', () {
      expect(PrivacyPolicyDialog.defaultPrivacyUrl, 'https://staging-saas.redtaxi.co.uk/privacy-policy');
      expect(PrivacyPolicyDialog.defaultTermsUrl, 'https://staging-saas.redtaxi.co.uk/terms-and-conditions');
    });
  });
}
