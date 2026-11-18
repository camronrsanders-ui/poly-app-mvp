import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

// Photo uploads PR 2 (honest rejections + honest errors) — design
// photo-uploads-design-2026-11-18.md §4 + §5, adopted Decisions 3a
// (a rejected member sees a server-owned reason CODE mapped to plain
// guidance, never the raw stored value) and 5 (the fixed moderator
// taxonomy). The behavioral mapping itself is unit-tested in
// functions/test/profile_media_rejection.test.cjs; these pins keep
// the wiring — module, listing DTO, review callable, client DTO, UI
// copy, error split — from quietly reverting to raw passthrough or a
// single catch-all message.

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const taxonomy = read('functions/src/profile_media_rejection.ts');
const listing = read('functions/src/profile_media_listing.ts');
const media = read('functions/src/profile_media.ts');
const service = read('lib/services/profile_media_service.dart');
const screen = read('lib/screens/profile/profile_photos_screen.dart');

test('rejection taxonomy module carries exactly the adopted code sets', () => {
  for (const code of [
    'upload_validation',
    'invalid_processing_state',
    'storage_validation',
    'content_type_mismatch',
    'image_processing',
  ]) {
    assert.match(taxonomy, new RegExp(`'${code}'`), `machine code ${code} missing`);
  }
  for (const code of ['community_guidelines', 'image_quality', 'other_policy']) {
    assert.match(taxonomy, new RegExp(`'${code}'`), `moderator code ${code} missing`);
  }
  assert.match(taxonomy, /fallbackRejectionReasonCode = 'moderation_policy'/);
  assert.match(taxonomy, /export function rejectionReasonCodeForDisplay/);
  assert.match(taxonomy, /export function moderatorRejectionReasonToStore/);
});

test('owner listing DTO carries the mapped reason code and never the raw stored reason', () => {
  assert.match(
    listing,
    /rejectionReasonCode:\s*rejectionReasonCodeForDisplay\(doc\.get\('rejectionReason'\)\)/,
  );
  // Only rejected photos carry a code.
  assert.match(listing, /status === 'rejected'/);
  // The raw stored field is read only to be mapped: it is never a DTO
  // key of its own (rejectionReasonCode: is a different key and does
  // not match this pattern).
  assert.doesNotMatch(listing, /rejectionReason:/);
});

test('review callable stores only adopted moderator codes', () => {
  assert.match(media, /rejectionReason: moderatorRejectionReasonToStore\(request\.data\?\.reason\)/);
  // The free-text store (arbitrary reviewer text, 160-char slice) is gone.
  assert.doesNotMatch(media, /rejectionReason: String\(request\.data/);
  assert.doesNotMatch(media, /slice\(0, 160\)/);
});

test('client DTO parses the reason code and the rejected row renders mapped guidance', () => {
  assert.match(service, /final String\? rejectionReasonCode;/);
  assert.match(service, /rejectionReasonCode: data\['rejectionReasonCode'\] as String\?/);
  assert.match(screen, /_rejectionGuidance\(photo\.rejectionReasonCode\)/);
  assert.match(screen, /too dark or blurry to approve/);
  assert.match(screen, /meet the community guidelines/);
  assert.match(screen, /couldn't be processed/);
});

test('upload errors split by failure kind instead of one catch-all message', () => {
  assert.match(screen, /on FirebaseFunctionsException catch \(error\)/);
  assert.match(screen, /profilePhotoUploadErrorMessage\(error\.code\)/);
  assert.match(screen, /daily photo limit/);
  assert.match(screen, /check your connection and try again/);
  assert.match(screen, /Could not upload that photo\. Please try again\./);
});
