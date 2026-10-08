import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const cleanup = fs.readFileSync(
  path.join(root, 'functions/src/circle_account_cleanup.ts'),
  'utf8',
);
const entry = fs.readFileSync(
  path.join(root, 'functions/src/entry.ts'),
  'utf8',
);

test('Circle account cleanup is exported and tied to deletion-pending state', () => {
  assert.match(entry, /cleanupCircleDataForDeletingAccount/);
  assert.match(cleanup, /onDocumentUpdated/);
  assert.match(cleanup, /document:\s*'users\/\{uid\}'/);
  assert.match(cleanup, /accountStatus'\) === 'paused'/);
  assert.match(cleanup, /deletionRequestedAt'\) != null/);
});

test('Circle account cleanup covers ownership, membership and invitations', () => {
  for (const collection of [
    'circles',
    'circle_memberships',
    'circle_invites',
  ]) {
    assert.match(
      cleanup,
      new RegExp(`collection\\('${collection}'\\)`),
      `${collection} must participate in account deletion cleanup`,
    );
  }

  assert.match(cleanup, /where\('ownerUid',\s*'==',\s*uid\)/);
  assert.match(cleanup, /where\('uid',\s*'==',\s*uid\)/);
  assert.match(cleanup, /where\('inviteeUid',\s*'==',\s*uid\)/);
  assert.match(cleanup, /where\('inviterUid',\s*'==',\s*uid\)/);
  assert.match(cleanup, /FieldValue\.increment\(-1\)/);
});

test('active non-owner membership deletion and count adjustment are atomic', () => {
  assert.match(cleanup, /runTransaction/);
  assert.match(cleanup, /transaction\.get\(membershipRef\)/);
  assert.match(cleanup, /transaction\.delete\(membershipRef\)/);
  assert.match(cleanup, /transaction\.update\(circleRef/);
  assert.match(cleanup, /atomicallyRemovedMembershipPaths/);

  assert.doesNotMatch(
    cleanup,
    /writer\.update\([\s\S]*memberCount:\s*FieldValue\.increment\(-1\)/,
    'memberCount must not be decremented separately from membership deletion',
  );
});

test('Circle account cleanup removes every user-scoped Circle rate limit', () => {
  for (const action of ['create', 'invite', 'respond', 'leave', 'list']) {
    assert.match(
      cleanup,
      new RegExp(`'${action}'`),
      `circle_${action} rate-limit state must be cleaned`,
    );
  }

  assert.match(cleanup, /`circle_\$\{action\}_\$\{uid\}`/);
});
