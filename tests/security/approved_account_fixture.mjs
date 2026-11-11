// Trusted, rules-disabled fixture for unrelated access-control tests.
// Real accounts require the App-Check-protected compliance callable instead.
export const approvedAccount = (uid, overrides = {}) => ({
  uid,
  accountStatus: 'active',
  adultAccessApproved: true,
  termsAcceptedVersion: '2026-08-alpha-v1',
  communityGuidelinesAcceptedVersion: '2026-08-v1',
  ...overrides,
});
