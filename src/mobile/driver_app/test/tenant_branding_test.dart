import 'package:driver_app/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tenant-info API sends brand colours as HSL strings and leaves
/// `primaryColour` as "" — these cover that exact shape.
void main() {
  // Real response of GET /api/v2/public/tenant-info (Insta-Taxi).
  const apiData = <String, dynamic>{
    'tenantId': 'org_704e02f990784140b639c331',
    'companyName': 'Insta-Taxi',
    'phone': '918756309374',
    'email': 'officialadarsh2023@gmail.com',
    'website': '',
    'logoUrl': '',
    'primaryColour': '',
    'primaryHsl': '200 98% 39%',
    'secondaryHsl': '27 31% 94%',
  };

  Color hsl(double h, double s, double l) =>
      HSLColor.fromAHSL(1, h, s, l).toColor();

  group('parseHsl', () {
    test('space separated (the API format)', () {
      expect(TenantBranding.parseHsl('200 98% 39%'), hsl(200, .98, .39));
    });
    test('comma separated and hsl() wrappers', () {
      final expected = hsl(200, .98, .39);
      expect(TenantBranding.parseHsl('200, 98%, 39%'), expected);
      expect(TenantBranding.parseHsl('hsl(200 98% 39%)'), expected);
      expect(TenantBranding.parseHsl('hsl(200, 98%, 39%)'), expected);
      expect(TenantBranding.parseHsl('HSL(200deg 98% 39%)'), expected);
    });
    test('wraps hue and clamps saturation/lightness', () {
      expect(TenantBranding.parseHsl('560 98% 39%'), hsl(200, .98, .39));
      expect(TenantBranding.parseHsl('10 150% 120%'), hsl(10, 1, 1));
    });
    test('rejects junk', () {
      expect(TenantBranding.parseHsl(''), isNull);
      expect(TenantBranding.parseHsl('blue'), isNull);
      expect(TenantBranding.parseHsl('#ff0000'), isNull);
      expect(TenantBranding.parseHsl(null), isNull);
      expect(TenantBranding.parseHsl(42), isNull);
    });
  });

  group('fromJson', () {
    test('uses HSL when primaryColour is blank', () {
      final b = TenantBranding.fromJson({'success': true, 'data': apiData});
      expect(b.name, 'Insta-Taxi');
      expect(b.primaryColor, hsl(200, .98, .39));
      expect(b.secondaryColor, hsl(27, .31, .94));
      expect(b.dispatchPhone, '918756309374');
    });

    test('a real hex colour still wins over HSL', () {
      final b = TenantBranding.fromJson({
        ...apiData,
        'primaryColour': '#FF0000',
      });
      expect(b.primaryColor, const Color(0xFFFF0000));
    });

    test('no colours at all falls back to the defaults', () {
      final b = TenantBranding.fromJson({
        'companyName': 'X',
        'tenantId': 't',
      });
      expect(b.primaryColor, const Color(0xFFD32F2F));
      expect(b.secondaryColor, const Color(0xFFF8F9FA));
    });

    test('survives a save/load round trip (secondary + sync time)', () {
      final synced = DateTime.utc(2026, 11, 13, 13, 18);
      final b = TenantBranding.fromJson(apiData).copyWith(syncedAt: synced);
      final back = TenantBranding.fromJson(b.toJson());
      expect(back.primaryColor, b.primaryColor);
      expect(back.secondaryColor, b.secondaryColor);
      expect(back.name, 'Insta-Taxi');
      expect(back.syncedAt, synced);
    });
  });

  group('helpers', () {
    test('payloadHasColours', () {
      expect(TenantBranding.payloadHasColours(apiData), isTrue);
      expect(
        TenantBranding.payloadHasColours({'companyName': 'X', 'primaryColour': ''}),
        isFalse,
      );
      expect(TenantBranding.payloadHasColours({'primaryColour': '#123456'}), isTrue);
    });

    test('sameLookAs ignores the sync timestamp', () {
      final a = TenantBranding.fromJson(apiData);
      final b = a.copyWith(syncedAt: DateTime.now());
      expect(a.sameLookAs(b), isTrue);
      final changed = TenantBranding.fromJson({...apiData, 'primaryHsl': '10 80% 40%'});
      expect(a.sameLookAs(changed), isFalse);
    });

    test('onPrimaryColor picks readable text', () {
      expect(TenantBranding.fromJson(apiData).onPrimaryColor, Colors.white);
      final pale = TenantBranding.fromJson({...apiData, 'primaryHsl': '50 100% 85%'});
      expect(pale.onPrimaryColor, isNot(Colors.white));
    });
  });

  group('theme', () {
    test('light theme uses the tenant primary and a light secondary background', () {
      final b = TenantBranding.fromJson(apiData);
      final t = AppTheme.getDynamicLightTheme(b);
      expect(t.colorScheme.primary, b.primaryColor);
      expect(t.scaffoldBackgroundColor, b.secondaryColor);
      expect(t.appBarTheme.backgroundColor, b.primaryColor);
    });

    test('a dark secondary is not used as the page background', () {
      final b = TenantBranding.fromJson({...apiData, 'secondaryHsl': '220 40% 20%'});
      final t = AppTheme.getDynamicLightTheme(b);
      expect(t.scaffoldBackgroundColor, AppTheme.lightBackground);
    });
  });
}
