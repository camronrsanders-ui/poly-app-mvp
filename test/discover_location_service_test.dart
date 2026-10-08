import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/services/discover_location_service.dart';

void main() {
  test('parses a valid foreground location sample', () {
    final outcome = DiscoverLocationOutcome.fromPlatformValue({
      'status': 'ready',
      'latitude': 12.3456,
      'longitude': -45.6789,
      'accuracyMeters': 250,
      'observedAtMs': 1800000000000,
    });

    expect(outcome.status, DiscoverLocationStatus.ready);
    expect(outcome.sample?.latitude, 12.3456);
    expect(outcome.sample?.longitude, -45.6789);
    expect(outcome.sample?.accuracyMeters, 250);
  });

  test('maps denied, restricted, and disabled platform states', () {
    expect(
      DiscoverLocationOutcome.fromPlatformValue({'status': 'denied'}).status,
      DiscoverLocationStatus.denied,
    );
    expect(
      DiscoverLocationOutcome.fromPlatformValue({'status': 'restricted'})
          .status,
      DiscoverLocationStatus.restricted,
    );
    expect(
      DiscoverLocationOutcome.fromPlatformValue({
        'status': 'services_disabled',
      }).status,
      DiscoverLocationStatus.servicesDisabled,
    );
  });

  test('invalid or missing precise coordinates fail closed', () {
    for (final payload in <Object?>[
      null,
      'not-a-map',
      {'status': 'ready'},
      {
        'status': 'ready',
        'latitude': 91,
        'longitude': 0,
        'accuracyMeters': 10,
        'observedAtMs': 1800000000000,
      },
      {
        'status': 'ready',
        'latitude': 0,
        'longitude': -181,
        'accuracyMeters': 10,
        'observedAtMs': 1800000000000,
      },
    ]) {
      expect(
        DiscoverLocationOutcome.fromPlatformValue(payload).status,
        DiscoverLocationStatus.unavailable,
      );
    }
  });
}
