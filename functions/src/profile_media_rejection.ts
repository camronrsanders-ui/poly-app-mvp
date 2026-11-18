// H-9 (photo uploads PR 2): the member-facing taxonomy for
// profile-photo rejections, extracted in the repo's testable-module
// pattern so the mapping is unit-tested without a database.
//
// The stored `rejectionReason` field is a mixed legacy taxonomy: five
// machine codes written by the upload/processing pipeline, arbitrary
// free text from the QA-era moderation client, and the bare
// 'moderation' default. Raw stored values must never cross the API
// (the moderation runbook mandates machine-safe codes and no free-text
// moderator notes), so the listing maps every stored value onto a
// small display taxonomy, and the review callable only ever stores
// codes from the adopted moderator set — every rejection written from
// the day this ships is display-safe by construction.
// Design: photo-uploads-design-2026-11-18.md §4, adopted Decisions
// 3a (reason code mapped to plain guidance) and 5 (fixed taxonomy).

/** Codes written by the pipeline itself (no human involved). */
export const machineRejectionReasonCodes = [
  'upload_validation',
  'invalid_processing_state',
  'storage_validation',
  'content_type_mismatch',
  'image_processing',
] as const;

/** The adopted fixed set a human reviewer may choose (Decision 5). */
export const moderatorRejectionReasonCodes = [
  'community_guidelines',
  'image_quality',
  'other_policy',
] as const;

/** The single display code every unrecognized stored value maps to. */
export const fallbackRejectionReasonCode = 'moderation_policy';

const displayableCodes = new Set<string>([
  ...machineRejectionReasonCodes,
  ...moderatorRejectionReasonCodes,
  fallbackRejectionReasonCode,
]);

const moderatorCodeSet = new Set<string>(moderatorRejectionReasonCodes);

function normalizedCode(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

/**
 * Maps a stored `rejectionReason` value onto the member-facing display
 * taxonomy. Known machine and moderator codes pass through as
 * themselves; anything else — legacy free text, the QA string
 * 'local_moderation_qa', the bare 'moderation' default, a missing or
 * non-string value — maps to 'moderation_policy'. The raw stored text
 * never crosses the API.
 */
export function rejectionReasonCodeForDisplay(storedReason: unknown): string {
  const code = normalizedCode(storedReason);
  return displayableCodes.has(code) ? code : fallbackRejectionReasonCode;
}

/**
 * Constrains a reviewer-supplied reason to the adopted moderator code
 * set before it is stored. Anything outside the set — free text, a
 * machine code, the QA string, a missing value — stores as
 * 'moderation_policy'.
 */
export function moderatorRejectionReasonToStore(requestedReason: unknown): string {
  const code = normalizedCode(requestedReason);
  return moderatorCodeSet.has(code) ? code : fallbackRejectionReasonCode;
}
