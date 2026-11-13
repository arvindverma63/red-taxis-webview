import 'package:driver_app/features/auth/presentation/widgets/fleet_qr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drivers paste the Tenant ID and key as one value, or with quotes/spaces.
/// The server rejects "org_x:rtk_y" as an ID (and the key stays empty), which
/// used to leave the app on "First Taxis" with no explanation.
void main() {
  const id = 'org_704e02f990784140b639c331';
  const key = 'rtk_pub_a57ba6db24b7631da368ce7cd3a2564222f7cd36d2840ee1d200740a68a145f5';

  test('separate, clean fields are untouched', () {
    final r = normalizeTenantCredentials(id, key);
    expect(r.tenantId, id);
    expect(r.tenantKey, key);
  });

  test('surrounding spaces and quotes are removed', () {
    final r = normalizeTenantCredentials('  "$id"  ', " '$key' ");
    expect(r.tenantId, id);
    expect(r.tenantKey, key);
  });

  test('id:key pasted into the Tenant ID field is split', () {
    final r = normalizeTenantCredentials('$id:$key', '');
    expect(r.tenantId, id);
    expect(r.tenantKey, key);
  });

  test('other separators work too: space, pipe, comma, newline', () {
    for (final sep in [' ', '|', ',', ';', '\n', ' : ']) {
      final r = normalizeTenantCredentials('$id$sep$key', '');
      expect(r.tenantId, id, reason: 'separator "$sep"');
      expect(r.tenantKey, key, reason: 'separator "$sep"');
    }
  });

  test('a key typed in the key field wins over the one in the ID field', () {
    final r = normalizeTenantCredentials('$id:old_key', 'typed_key');
    expect(r.tenantId, id);
    expect(r.tenantKey, 'typed_key');
  });

  test('the pair pasted into the key field is split', () {
    final r = normalizeTenantCredentials('', '$id:$key');
    expect(r.tenantId, id);
    expect(r.tenantKey, key);
    final r2 = normalizeTenantCredentials(id, '$id:$key');
    expect(r2.tenantId, id);
    expect(r2.tenantKey, key);
  });

  test('an ID with junk after it falls back to its first token', () {
    final r = normalizeTenantCredentials('hello world', '');
    expect(r.tenantId, 'hello');
  });

  test('empty stays empty', () {
    final r = normalizeTenantCredentials('', '');
    expect(r.tenantId, '');
    expect(r.tenantKey, '');
  });

  test('demo preset ids are unchanged', () {
    final r = normalizeTenantCredentials('org_ace_taxis', 'tk_live_ace_staging_2026');
    expect(r.tenantId, 'org_ace_taxis');
    expect(r.tenantKey, 'tk_live_ace_staging_2026');
  });
}
