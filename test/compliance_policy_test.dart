import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/config/compliance_policy.dart';

void main() {
  test('age calculation respects the birthday boundary', () {
    final birthDate = DateTime(2008, 8, 15);
    expect(ageOnDate(birthDate, DateTime(2026, 8, 14)), 17);
    expect(ageOnDate(birthDate, DateTime(2026, 8, 15)), 18);
  });

  test('current compliance requires adult approval and both policy versions',
      () {
    expect(accountHasCurrentCompliance(<String, dynamic>{}), isFalse);
    expect(
      accountHasCurrentCompliance(<String, dynamic>{
        'adultAccessApproved': true,
        'termsAcceptedVersion': currentTermsVersion,
        'communityGuidelinesAcceptedVersion': currentCommunityGuidelinesVersion,
      }),
      isTrue,
    );
    expect(
      accountHasCurrentCompliance(<String, dynamic>{
        'adultAccessApproved': true,
        'termsAcceptedVersion': 'stale-version',
        'communityGuidelinesAcceptedVersion': currentCommunityGuidelinesVersion,
      }),
      isFalse,
    );
  });

  test('age assurance methods are intentionally bounded', () {
    expect(allowedAgeAssuranceMethods, contains('apple_declared_age_range'));
    expect(allowedAgeAssuranceMethods, contains('play_age_signals'));
    expect(allowedAgeAssuranceMethods, contains('self_attested_dob_fallback'));
  });
}
