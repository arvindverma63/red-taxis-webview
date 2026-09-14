import 'package:customer_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

AppConfig _config({required int opening, required int closing}) => AppConfig(
      tenantOrgId: 'org_test',
      tenantKey: 'rtk_test',
      brandName: 'Test Taxis',
      supportPhone: '',
      apiBaseUrl: 'https://example.test',
      pusherKey: 'key',
      pusherCluster: 'eu',
      openingHour: opening,
      closingHour: closing,
    );

void main() {
  group('AppConfig.isOutsideOperatingHours', () {
    test('daytime window: inside hours returns false', () {
      final c = _config(opening: 7, closing: 22);
      expect(c.isOutsideOperatingHours(7), isFalse); // open boundary inclusive
      expect(c.isOutsideOperatingHours(12), isFalse);
      expect(c.isOutsideOperatingHours(21), isFalse);
    });

    test('daytime window: outside hours returns true', () {
      final c = _config(opening: 7, closing: 22);
      expect(c.isOutsideOperatingHours(6), isTrue);
      expect(c.isOutsideOperatingHours(22), isTrue); // close boundary exclusive
      expect(c.isOutsideOperatingHours(2), isTrue);
    });

    test('overnight window (open 06:00, close 02:00) wraps midnight', () {
      final c = _config(opening: 6, closing: 2);
      // Open through the evening and across midnight until close.
      expect(c.isOutsideOperatingHours(10), isFalse);
      expect(c.isOutsideOperatingHours(23), isFalse);
      expect(c.isOutsideOperatingHours(1), isFalse);
      // Closed in the early-morning gap before reopening.
      expect(c.isOutsideOperatingHours(2), isTrue);
      expect(c.isOutsideOperatingHours(4), isTrue);
      expect(c.isOutsideOperatingHours(5), isTrue);
    });
  });
}
