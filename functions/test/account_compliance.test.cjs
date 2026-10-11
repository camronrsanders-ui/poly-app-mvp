const assert = require('node:assert/strict');
const test = require('node:test');

const {
  CURRENT_COMMUNITY_GUIDELINES_VERSION,
  CURRENT_TERMS_VERSION,
  isActiveCompliantMember,
} = require('../lib/account_compliance.js');

function snapshot(data, exists = true) {
  return {
    exists,
    data: () => data,
    get: (field) => data?.[field],
  };
}

test('active new-format account requires approved adult access and current policies', () => {
  assert.equal(isActiveCompliantMember(snapshot({
    accountStatus: 'active',
    adultAccessApproved: true,
    termsAcceptedVersion: CURRENT_TERMS_VERSION,
    communityGuidelinesAcceptedVersion: CURRENT_COMMUNITY_GUIDELINES_VERSION,
  })), true);

  assert.equal(isActiveCompliantMember(snapshot({
    accountStatus: 'active',
    adultAccessApproved: false,
    termsAcceptedVersion: CURRENT_TERMS_VERSION,
    communityGuidelinesAcceptedVersion: CURRENT_COMMUNITY_GUIDELINES_VERSION,
  })), false);

  assert.equal(isActiveCompliantMember(snapshot({
    accountStatus: 'active',
    adultAccessApproved: true,
    termsAcceptedVersion: 'stale-terms',
    communityGuidelinesAcceptedVersion: CURRENT_COMMUNITY_GUIDELINES_VERSION,
  })), false);

  assert.equal(isActiveCompliantMember(snapshot({
    accountStatus: 'active',
    adultAccessApproved: true,
    termsAcceptedVersion: CURRENT_TERMS_VERSION,
    communityGuidelinesAcceptedVersion: 'stale-guidelines',
  })), false);
});

test('inactive or missing accounts never pass member compliance', () => {
  assert.equal(isActiveCompliantMember(snapshot({
    accountStatus: 'suspended',
    adultAccessApproved: true,
    termsAcceptedVersion: CURRENT_TERMS_VERSION,
    communityGuidelinesAcceptedVersion: CURRENT_COMMUNITY_GUIDELINES_VERSION,
  })), false);
  assert.equal(isActiveCompliantMember(snapshot({}, false)), false);
});

test('legacy active account without approval or policy fields fails closed', () => {
  assert.equal(isActiveCompliantMember(snapshot({accountStatus: 'active'})), false);
  assert.equal(isActiveCompliantMember(snapshot({
    accountStatus: 'active',
    adultAccessApproved: null,
    termsAcceptedVersion: CURRENT_TERMS_VERSION,
    communityGuidelinesAcceptedVersion: CURRENT_COMMUNITY_GUIDELINES_VERSION,
  })), false);
});

test('partial adult and policy records cannot grant member access', () => {
  const baseline = {
    accountStatus: 'active',
    adultAccessApproved: true,
    termsAcceptedVersion: CURRENT_TERMS_VERSION,
    communityGuidelinesAcceptedVersion: CURRENT_COMMUNITY_GUIDELINES_VERSION,
  };
  for (const missingField of [
    'adultAccessApproved',
    'termsAcceptedVersion',
    'communityGuidelinesAcceptedVersion',
  ]) {
    const partial = {...baseline};
    delete partial[missingField];
    assert.equal(isActiveCompliantMember(snapshot(partial)), false, missingField);
  }
});
