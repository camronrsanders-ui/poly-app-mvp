import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const service = fs.readFileSync(
  'lib/services/circle_membership_service.dart',
  'utf8',
);

test('Circle client uses callable backend only', () => {
  assert.match(
    service,
    /httpsCallable\('createCircle'\)/,
  );

  assert.match(
    service,
    /httpsCallable\('listMyCircles'\)/,
  );

  assert.match(
    service,
    /inviteCircleMember/,
  );

  assert.match(
    service,
    /respondToCircleInvite/,
  );

  assert.match(
    service,
    /httpsCallable\('leaveCircle'\)/,
  );
});

test('Circle client does not directly access Firestore', () => {
  assert.doesNotMatch(
    service,
    /cloud_firestore/,
  );

  assert.doesNotMatch(
    service,
    /FirebaseFirestore/,
  );
});

test('Circle membership and invitations remain separate models', () => {
  assert.match(
    service,
    /class CircleSummary/,
  );

  assert.match(
    service,
    /class CircleInviteSummary/,
  );

  assert.match(
    service,
    /class CircleMembershipSnapshot/,
  );
});
