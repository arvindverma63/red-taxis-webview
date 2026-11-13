import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/widgets/branded_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fleet's own logo is used when it has one; otherwise the bundled
/// default logo is shown.
void main() {
  const base = 'https://staging-api.redtaxi.co.uk';

  TenantBranding branding(Map<String, dynamic> extra) => TenantBranding.fromJson({
        'tenantId': 'org_x',
        'companyName': 'Insta-Taxi',
        'primaryHsl': '200 98% 39%',
        ...extra,
      });

  group('logo parsing', () {
    test('blank logoUrl (what the API sends when none is uploaded) is null', () {
      final b = branding({'logoUrl': ''});
      expect(b.logoLightUrl, isNull);
      expect(b.logoDarkUrl, isNull);
      expect(b.symbolUrl, isNull);
    });

    test('a real logoUrl is used for light and dark', () {
      final b = branding({'logoUrl': 'https://cdn.example.com/logo.png'});
      expect(b.logoLightUrl, 'https://cdn.example.com/logo.png');
      expect(b.logoDarkUrl, 'https://cdn.example.com/logo.png');
    });

    test('a blank specific logo does not hide a real logoUrl', () {
      final b = branding({
        'branding': {
          'logos': {'lightUrl': '', 'darkUrl': '  '},
        },
        'logoUrl': 'https://cdn.example.com/logo.png',
      });
      expect(b.logoLightUrl, 'https://cdn.example.com/logo.png');
      expect(b.logoDarkUrl, 'https://cdn.example.com/logo.png');
    });

    test('logos survive a save/load round trip', () {
      final b = branding({'logoUrl': 'https://cdn.example.com/logo.png'});
      final back = TenantBranding.fromJson(b.toJson());
      expect(back.logoLightUrl, 'https://cdn.example.com/logo.png');
    });
  });

  group('absoluteUrl', () {
    test('keeps full addresses, fixes relative ones, drops blanks', () {
      expect(TenantBranding.absoluteUrl('https://a.com/l.png', base), 'https://a.com/l.png');
      expect(TenantBranding.absoluteUrl('//cdn.a.com/l.png', base), 'https://cdn.a.com/l.png');
      expect(TenantBranding.absoluteUrl('/uploads/l.png', base), '$base/uploads/l.png');
      expect(TenantBranding.absoluteUrl('uploads/l.png', base), '$base/uploads/l.png');
      expect(TenantBranding.absoluteUrl('/uploads/l.png', '$base/'), '$base/uploads/l.png');
      expect(TenantBranding.absoluteUrl('', base), isNull);
      expect(TenantBranding.absoluteUrl('   ', base), isNull);
      expect(TenantBranding.absoluteUrl(null, base), isNull);
    });

    test('withAbsoluteLogos fixes every logo and keeps the rest', () {
      final b = branding({'logoUrl': '/uploads/logo.png'}).withAbsoluteLogos(base);
      expect(b.logoLightUrl, '$base/uploads/logo.png');
      expect(b.logoDarkUrl, '$base/uploads/logo.png');
      expect(b.name, 'Insta-Taxi');
      expect(b.primaryColor, branding({}).primaryColor);
    });
  });

  group('BrandedLogo', () {
    Future<Image> pumpLogo(WidgetTester tester, TenantBranding b) async {
      await tester.pumpWidget(
        MaterialApp(home: Center(child: BrandedLogo(branding: b, size: 60))),
      );
      return tester.widget<Image>(find.byType(Image).first);
    }

    testWidgets('no logo uploaded -> bundled default logo', (tester) async {
      final image = await pumpLogo(tester, branding({'logoUrl': ''}));
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, 'assets/images/logo.png');
    });

    testWidgets('logo uploaded -> that logo is loaded from its address', (tester) async {
      final image = await pumpLogo(
        tester,
        branding({'logoUrl': 'https://cdn.example.com/logo.png'}),
      );
      expect(image.image, isA<NetworkImage>());
      expect((image.image as NetworkImage).url, 'https://cdn.example.com/logo.png');
    });

    testWidgets('a blank light logo falls through to the symbol logo', (tester) async {
      final image = await pumpLogo(
        tester,
        branding({
          'branding': {
            'logos': {'lightUrl': '', 'symbolUrl': 'https://cdn.example.com/s.png'},
          },
        }),
      );
      expect((image.image as NetworkImage).url, 'https://cdn.example.com/s.png');
    });

    testWidgets('an address that is not a web address -> default logo', (tester) async {
      final image = await pumpLogo(tester, branding({'logoUrl': '/uploads/logo.png'}));
      expect(image.image, isA<AssetImage>());
    });
  });
}
