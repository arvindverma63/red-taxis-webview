import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/core/update/app_update_service.dart';

void main() {
  test('isNewerVersion compares dotted versions numerically', () {
    expect(isNewerVersion('1.0.2', '1.0.1'), isTrue);
    expect(isNewerVersion('1.1.0', '1.0.9'), isTrue);
    expect(isNewerVersion('2.0', '1.9.9'), isTrue);
    expect(isNewerVersion('1.0.10', '1.0.9'), isTrue);
    expect(isNewerVersion('1.0.1', '1.0.1'), isFalse);
    expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
    expect(isNewerVersion('1.0.1+5', '1.0.1'), isFalse);
  });
}
