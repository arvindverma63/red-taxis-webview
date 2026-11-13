import 'package:customer_app/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The iOS Pusher plugin force-casts the authorizer reply to [String: String]
/// and force-unwraps "auth", so anything else must come back as null.
void main() {
  test('valid auth reply passes through as string map', () {
    final out = TrackingRepository.safeAuthPayload({'auth': 'key:sig'});
    expect(out, {'auth': 'key:sig'});
  });

  test('JSON string reply is decoded', () {
    final out = TrackingRepository.safeAuthPayload('{"auth":"k:s"}');
    expect(out, {'auth': 'k:s'});
  });

  test('non-string values are stringified, never left as objects', () {
    final out = TrackingRepository.safeAuthPayload({
      'auth': 'k:s',
      'channel_data': {'user_id': 7},
      'shared_secret': 12345,
    });
    expect(out!['auth'], 'k:s');
    expect(out['channel_data'], '{"user_id":7}');
    expect(out['shared_secret'], '12345');
  });

  test('empty, missing-auth, wrong-type and garbage replies become null', () {
    expect(TrackingRepository.safeAuthPayload(null), isNull);
    expect(TrackingRepository.safeAuthPayload(<String, dynamic>{}), isNull);
    expect(TrackingRepository.safeAuthPayload({'auth': ''}), isNull);
    expect(TrackingRepository.safeAuthPayload({'auth': 5}), isNull);
    expect(TrackingRepository.safeAuthPayload('not json'), isNull);
    expect(TrackingRepository.safeAuthPayload([1, 2]), isNull);
  });
}
