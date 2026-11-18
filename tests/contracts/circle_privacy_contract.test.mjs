import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const index = read('functions/src/index.ts');
const circle = read('functions/src/circle_view.ts');
const circleVisibility = read('functions/src/circle_view_visibility.ts');
const rules = read('firestore.rules');

test('Circle profile view is exported through the trusted Functions entrypoint', () => {
  assert.match(circle, /export const getCircleForProfile\b/);
  assert.match(index, /export \{getCircleForProfile\} from '.\/circle_view'/);
  assert.match(circle, /enforceAppCheck:\s*true/);
});

test('global Circle visibility is enforced before card visibility', () => {
  assert.match(circle, /mapVisibility/);
  assert.match(circle, /mapVisibility === 'private'/);
  assert.match(circle, /mapVisibility === 'matches_only' && !matched/);
});

test('non-owner Circle views withhold card names and notes at every visibility', () => {
  // H-10 supersedes the unnamed_public-only redaction: until a consent
  // path exists, every non-owner projection redacts identity; only the
  // owner's own view includes name and note. The field logic lives in
  // the unit-tested projection module (circle_card_projection.ts).
  const projection = read('functions/src/circle_card_projection.ts');
  assert.match(circle, /cards\.push\(safeCard\(card, true\)\);/);
  assert.doesNotMatch(circle, /visibility === 'unnamed_public'\)/);
  assert.match(circle, /projectCircleCard\(card\.id, card\.data\(\), redactIdentity\)/);
  assert.match(projection, /!redactIdentity && typeof data\.displayNameOptional/);
  assert.match(projection, /!redactIdentity && typeof data\.note/);
});

test('full relationship-card documents are owner-only and active-account-only in Firestore', () => {
  assert.match(
    rules,
    /match \/relationship_cards\/\{cardId\}[\s\S]*?allow read:\s*if signedIn\(\) && userIsActive\(request\.auth\.uid\)[\s\S]*?&& resource\.data\.ownerUid == request\.auth\.uid;/,
  );
});

test('Circle view rate-limit state is cleaned during account deletion', () => {
  assert.match(circle, /action\s*=\s*'circle_view'/);
  assert.match(index, /'circle_view'/);
});

test('check-in data never surfaces through the Circle profile projection', () => {
  // Bilateral check-ins are visible to exactly the two conversation
  // participants (Final Upgrade Phase 2 spec §3.2): the projection must
  // never read or expose the check-in collection or its fields.
  assert.doesNotMatch(circle, /connection_check_ins/);
  assert.doesNotMatch(circle, /checkIn|sharedNote/);
  // The collection itself stays callable-only in the rules.
  assert.match(
    rules,
    /match \/connection_check_ins\/\{conversationId\} \{ allow read, write: if false; \}/,
  );
});

test('profile visibility caps the Circle read for non-owners before the map gate', () => {
  // H-11: getCircleForProfile must honor profileVisibility, not only
  // mapVisibility. The cap is computed from the profile document, runs
  // only inside the non-owner branch, denies with permission-denied (the
  // one code the client already maps to the "not shared" state), and is
  // evaluated before both the mapVisibility gate and the card read.
  assert.match(
    circle,
    /import \{circleProfileVisibilityDenial\} from '.\/circle_view_visibility'/,
  );
  const nonOwnerGate = circle.indexOf('if (!isOwner) {');
  const capCall = circle.indexOf('const profileDenial = circleProfileVisibilityDenial(');
  const mapGate = circle.indexOf("mapVisibility === 'private'");
  const cardRead = circle.indexOf(".collection('relationship_cards')");
  assert.ok(nonOwnerGate !== -1 && capCall > nonOwnerGate);
  assert.ok(capCall !== -1 && capCall < mapGate);
  assert.ok(capCall < cardRead);
  assert.match(circle, /profile\.get\('profileVisibility'\)/);
  assert.match(
    circle,
    /if \(profileDenial !== null\) \{\s*throw new HttpsError\('permission-denied', profileDenial\);/,
  );
  // The two-gate composition is this function's own job: it must not
  // delegate to the profile-view helper, which knows nothing of maps.
  assert.doesNotMatch(circle, /import \{canViewOwnerProfile\} from '.\/profile_access'/);
});

test('the profile visibility cap mirrors the canonical profile gate semantics', () => {
  // Same semantics as canViewOwnerProfile (profile_access.ts): public
  // allows, matches_only requires an active match, and hidden, missing,
  // or unrecognized values fail closed. The hidden denial uses the same
  // generic message as the block denial so it never reveals the setting.
  assert.match(circleVisibility, /String\(profileVisibility \?\? 'hidden'\)/);
  assert.match(circleVisibility, /visibility === 'public'\) return null;/);
  assert.match(circleVisibility, /visibility === 'matches_only'\) \{\s*return matched \? null : 'Circle is available to connections only\.';/);
  assert.match(circleVisibility, /return 'Circle is unavailable\.';/);
});

test('the owner path through the Circle read stays intact', () => {
  // The cap never applies to the owner: owners still receive every
  // active card, including private ones, with names and notes unredacted.
  assert.match(circle, /const isOwner = requesterUid === ownerUid;/);
  assert.match(circle, /if \(isOwner\) \{\s*cards\.push\(safeCard\(card, false\)\);/);
});
