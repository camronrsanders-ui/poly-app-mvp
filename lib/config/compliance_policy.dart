const int polycircleMinimumAge = 18;

// These versions intentionally identify the current pre-release policy text.
// Public distribution remains blocked until qualified legal review approves
// the final Terms/Privacy documents and these versions are advanced.
const String currentTermsVersion = '2026-08-alpha-v1';
const String currentCommunityGuidelinesVersion = '2026-08-v1';

const Set<String> allowedAgeAssuranceMethods = <String>{
  'apple_declared_age_range',
  'play_age_signals',
  'self_attested_dob_fallback',
};

bool accountHasCurrentCompliance(Map<String, dynamic>? account) {
  if (account == null) return false;
  return account['adultAccessApproved'] == true &&
      account['termsAcceptedVersion'] == currentTermsVersion &&
      account['communityGuidelinesAcceptedVersion'] ==
          currentCommunityGuidelinesVersion;
}

int ageOnDate(DateTime birthDate, DateTime onDate) {
  var age = onDate.year - birthDate.year;
  final birthdayHasOccurred = onDate.month > birthDate.month ||
      (onDate.month == birthDate.month && onDate.day >= birthDate.day);
  if (!birthdayHasOccurred) age--;
  return age;
}
