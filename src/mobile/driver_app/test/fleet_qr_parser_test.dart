import 'package:driver_app/features/auth/presentation/widgets/fleet_qr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts JSON, URL, delimited and bare ids', () {
    expect(parseFleetQr('{"tenantId":"org_ace_taxis","tenantKey":"k","name":"Ace"}').payload,
        {'tenantId': 'org_ace_taxis', 'tenantKey': 'k', 'companyName': 'Ace'});
    expect(parseFleetQr('redtaxis://fleet?tenantId=org_x1&tenantKey=rtk_1').payload?['tenantId'], 'org_x1');
    expect(parseFleetQr('org_abc:rtk_pub_1').payload?['tenantKey'], 'rtk_pub_1');
    expect(parseFleetQr('fleet_99|key|Name').payload?['companyName'], 'Name');
    expect(parseFleetQr('org_abc').isOk, isTrue);
  });

  test('rejects unsupported codes', () {
    for (final raw in [
      '',
      'hello world',
      'Hello: world',
      'https://example.com/menu',
      'WIFI:T:WPA;S:net;P:pass;;',
      '{"foo":"bar"}',
      'not json {',
    ]) {
      final r = parseFleetQr(raw);
      expect(r.isOk, isFalse, reason: raw);
      expect(r.failure, FleetQrFailure.unsupported, reason: raw);
    }
  });

  test('flags a malformed fleet id as invalid', () {
    expect(parseFleetQr('org_').failure, FleetQrFailure.invalid);
    expect(parseFleetQr('org_bad id!:key').failure, FleetQrFailure.invalid);
  });
}
