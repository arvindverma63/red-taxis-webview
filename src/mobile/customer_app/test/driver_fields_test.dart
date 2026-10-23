import 'package:customer_app/core/domain/driver_directory.dart';
import 'package:customer_app/core/domain/driver_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverFields.from', () {
    test('reads a nested driver object', () {
      final f = DriverFields.from({
        'driver': {
          'name': 'James Carter',
          'phone': '+44 7700 900123',
          'rating': '4.9',
          'plate': 'AC21 TXI',
          'vehicle': 'Toyota Prius',
          'vehicleColour': 'Black',
        },
      });
      expect(f.name, 'James Carter');
      expect(f.phone, '+44 7700 900123');
      expect(f.rating, 4.9);
      expect(f.plate, 'AC21 TXI');
      expect(f.vehicleDescription, 'Black Toyota Prius');
    });

    test('reads flat driverXxx keys', () {
      final f = DriverFields.from({
        'driverName': 'Sam Lee',
        'driverTelephone': '07700900456',
        'vehicleReg': 'BD71 XYZ',
        'vehicleModel': 'Skoda Octavia',
      });
      expect(f.name, 'Sam Lee');
      expect(f.phone, '07700900456');
      expect(f.plate, 'BD71 XYZ');
      expect(f.vehicleDescription, 'Skoda Octavia');
    });

    test('never throws on odd values and ignores a nested driver string', () {
      final f = DriverFields.from({
        'driver': '{"id":1}',
        'driverName': null,
        'driverRating': 'n/a',
      });
      expect(f.hasName, isFalse);
      expect(f.rating, isNull);
    });

    test('ignores out-of-range ratings', () {
      expect(DriverFields.from({'driverName': 'A', 'driverRating': 0}).rating,
          isNull);
      expect(DriverFields.from({'driverName': 'A', 'driverRating': 9}).rating,
          isNull);
    });
  });

  group('DriverDirectory', () {
    test('keeps known values when a later response omits them', () {
      DriverDirectory.remember(
        'b1',
        const DriverFields(name: 'Ann', phone: '0700', plate: 'AB12 CDE'),
      );
      DriverDirectory.remember(
        'b1',
        const DriverFields(name: 'Ann', vehicleMake: 'Tesla'),
      );
      final d = DriverDirectory.of('b1')!;
      expect(d.phone, '0700');
      expect(d.plate, 'AB12 CDE');
      expect(d.vehicleMake, 'Tesla');
    });

    test('ignores records without a driver name', () {
      DriverDirectory.remember('b2', const DriverFields(phone: '0700'));
      expect(DriverDirectory.of('b2'), isNull);
    });
  });
}
