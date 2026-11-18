import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

// Photo uploads PR 1 (listing correctness) — design
// photo-uploads-design-2026-11-18.md §3, adopted Decision 4a.
// The ordered queries below are only honest if the composite indexes in
// firestore.indexes.json exist: neither the emulator nor unit tests can
// detect a missing index (a deployed environment throws
// FAILED_PRECONDITION), so these pins are the CI-level guard.

const root = path.resolve(import.meta.dirname, '../..');
const listing = fs.readFileSync(path.join(root, 'functions/src/profile_media_listing.ts'), 'utf8');
const queue = fs.readFileSync(path.join(root, 'functions/src/profile_media_moderation.ts'), 'utf8');
const indexConfig = JSON.parse(fs.readFileSync(path.join(root, 'firestore.indexes.json'), 'utf8'));

function profileMediaIndex(fieldSequence) {
  return indexConfig.indexes.find((entry) => {
    if (entry.collectionGroup !== 'profile_media') return false;
    if (entry.fields.length !== fieldSequence.length) return false;
    return entry.fields.every((field, i) =>
      field.fieldPath === fieldSequence[i][0] && field.order === fieldSequence[i][1]);
  });
}

test('owner photo listing is ordered newest-first in the query with a bounded cap of 100', () => {
  assert.match(
    listing,
    /\.where\('ownerUid', '==', ownerUid\)\s*\.orderBy\('createdAt', 'desc'\)\s*\.limit\(100\)/,
  );
});

test('public photo listing filters to active photos inside the query, before the limit', () => {
  assert.match(
    listing,
    /\.where\('ownerUid', '==', ownerUid\)\s*\.where\('status', '==', 'active'\)\s*\.orderBy\('createdAt', 'desc'\)\s*\.limit\(20\)/,
  );
  // The filter-after-limit defect must not return: no in-memory status
  // filter and no in-memory sort anywhere in the listing module.
  assert.doesNotMatch(listing, /\.filter\(\(doc\) => doc\.get\('status'\) === 'active'\)/);
  assert.doesNotMatch(listing, /\.sort\(/);
});

test('moderation queue is ordered oldest-first by processedAt inside the query', () => {
  assert.match(
    queue,
    /\.where\('status', '==', 'processed_pending_review'\)\s*\.orderBy\('processedAt', 'asc'\)\s*\.limit\(limit\)/,
  );
  assert.doesNotMatch(queue, /photos\.sort\(/);
});

test('Firestore indexes include the profile_media listing composites', () => {
  assert.ok(
    profileMediaIndex([['ownerUid', 'ASCENDING'], ['createdAt', 'DESCENDING']]),
    'Missing composite index for the owner listing query (ownerUid, createdAt desc)',
  );
  assert.ok(
    profileMediaIndex([['ownerUid', 'ASCENDING'], ['status', 'ASCENDING'], ['createdAt', 'DESCENDING']]),
    'Missing composite index for the public listing query (ownerUid, status, createdAt desc)',
  );
});

test('Firestore indexes include the profile_media moderation-queue composite', () => {
  assert.ok(
    profileMediaIndex([['status', 'ASCENDING'], ['processedAt', 'ASCENDING']]),
    'Missing composite index for the moderation queue query (status, processedAt asc)',
  );
});
