import 'package:driver_app/features/auth/auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a driver sees when entering a Tenant ID / key fails. The API answers
/// 401 with one of these codes (checked against staging).
void main() {
  test('wrong key', () {
    final m = AuthNotifier.tenantErrorMessage(code: 'TENANT_KEY_INVALID', status: 401);
    expect(m, contains("access key isn't recognised"));
  });

  test('missing key', () {
    final m = AuthNotifier.tenantErrorMessage(code: 'TENANT_KEY_REQUIRED', status: 401);
    expect(m, contains('Enter the tenant access key'));
  });

  test('id and key do not belong together', () {
    final m = AuthNotifier.tenantErrorMessage(code: 'TENANT_MISMATCH', status: 401);
    expect(m, contains("doesn't match the access key"));
  });

  test('other 401/403 without a known code', () {
    expect(AuthNotifier.tenantErrorMessage(status: 401), contains("wasn't accepted"));
    expect(AuthNotifier.tenantErrorMessage(status: 403), contains("wasn't accepted"));
  });

  test('not found, offline and unknown', () {
    expect(AuthNotifier.tenantErrorMessage(status: 404), contains("couldn't find that fleet"));
    expect(AuthNotifier.tenantErrorMessage(offline: true), contains('internet connection'));
    expect(AuthNotifier.tenantErrorMessage(message: 'Boom'), contains('Boom'));
    expect(AuthNotifier.tenantErrorMessage(), contains("Couldn't verify this fleet"));
  });
}
