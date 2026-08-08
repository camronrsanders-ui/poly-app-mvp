import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/config/feature_flags.dart';

void main() {
  test('sensitive and future features remain disabled by default', () {
    expect(FeatureFlags.privateVaultEnabled, isFalse);
    expect(FeatureFlags.visualPolyculeGraphEnabled, isFalse);
    expect(FeatureFlags.aiCompatibilityEnabled, isFalse);
  });
}
