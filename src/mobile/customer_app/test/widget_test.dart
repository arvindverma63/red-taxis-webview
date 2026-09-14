import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/app.dart';
import 'package:customer_app/core/theme/theme.dart';
import 'package:customer_app/core/widgets/branded_logo.dart';
import 'package:customer_app/core/widgets/status_badge.dart';
import 'package:customer_app/features/booking/domain/booking_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Customer App Core Tests', () {
    test('TenantBranding default values and calculations', () {
      final branding = TenantBranding.defaultBranding();
      expect(branding.name, 'Ace Taxis');
      expect(branding.tenantId, 'org_ace_taxis');
      expect(branding.primaryColor, const Color(0xFFE50914));

      final json = branding.toJson();
      expect(json['tenantId'], 'org_ace_taxis');
      expect(json['companyName'], 'Ace Taxis');

      final fromJson = TenantBranding.fromJson(json);
      expect(fromJson.name, 'Ace Taxis');
      expect(fromJson.tenantId, 'org_ace_taxis');
    });

    test('VehicleOption default list and properties', () {
      final options = VehicleOption.defaultOptions;
      expect(options.length, 5);
      expect(options.first.name, 'Saloon');
      expect(options.first.capacity, 4);
      expect(options.first.basePrice, 12.50);
    });

    testWidgets('StatusBadge renders correct status and colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(status: 'driver_allocated'),
          ),
        ),
      );

      expect(find.text('DRIVER_ALLOCATED'), findsOneWidget);
    });

    testWidgets('BrandedLogo renders icon fallback gracefully', (WidgetTester tester) async {
      final branding = TenantBranding.defaultBranding();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandedLogo(branding: branding, size: 48),
          ),
        ),
      );

      expect(find.byType(BrandedLogo), findsOneWidget);
    });

    testWidgets('CustomerApp smoke test renders login on initial start', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: CustomerApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify sign in / welcome screen components
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Book as Guest'), findsOneWidget);
    });
  });
}
