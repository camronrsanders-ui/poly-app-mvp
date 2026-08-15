import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/services/age_assurance_service.dart';

void main() {
  test('18+ lower bound confirms adult access', () {
    final result = AgeAssuranceResult.fromPlatformMap(
      <String, dynamic>{
        'status': 'not_shared',
        'lowerBound': 18,
        'upperBound': null,
      },
      method: 'play_age_signals',
    );
    expect(result.decision, AgeAssuranceDecision.adult);
  });

  test('upper bound below 18 always blocks as minor', () {
    final result = AgeAssuranceResult.fromPlatformMap(
      <String, dynamic>{
        'status': 'adult',
        'lowerBound': 16,
        'upperBound': 17,
      },
      method: 'apple_declared_age_range',
    );
    expect(result.decision, AgeAssuranceDecision.minor);
  });

  test('verification required remains a blocking state', () {
    final result = AgeAssuranceResult.fromPlatformMap(
      <String, dynamic>{
        'status': 'verification_required',
        'regulatedRegion': true,
      },
      method: 'play_age_signals',
    );
    expect(result.decision, AgeAssuranceDecision.verificationRequired);
    expect(result.regulatedRegion, isTrue);
  });
}
