# Polycircle Data Lifecycle & Account Deletion

Privacy is a release requirement.

## Principles
- Collect only data needed for the product.
- Do not store exact location by default; use coarse city/region for MVP.
- Do not expose private relationship-card information in analytics/logs.
- Do not log message bodies, report details, email addresses, or private identity fields in application analytics.
- Relationship names typed by a user are unverified private user-generated content and must never imply the named person's consent.

## Current trusted account deletion behavior
Account deletion is implemented as the App-Check-protected callable `deleteMyAccount`. It requires the signed-in user to type `DELETE` and requires recent authentication before cleanup begins.

The current workflow:
1. rate-limits deletion attempts and immediately changes the account to `paused` so it stops behaving as an active account while cleanup runs;
2. deletes the user's relationship cards, outgoing/incoming likes, outgoing/incoming Pass state, blocks, Private Vault media metadata/grants/requests/preferences, profile-media metadata, and user-scoped rate-limit documents;
3. deactivates currently active matches and conversations that include the account without rewriting the actual `lastMessageAt` chronology or overwriting older end history;
4. deletes message documents sent by the deleting user;
5. anonymizes the deleting user's identity in retained report documents rather than exposing the deleted UID as the reporter/reported account;
6. deletes the user's profile document;
7. deletes protected profile-media and Private Vault Storage prefixes, including quarantine prefixes;
8. only after privacy-critical Firestore/Storage cleanup succeeds, overwrites the user document with a minimal paused deletion-recovery marker that contains no email/profile/activity fields;
9. deletes the Firebase Auth identity; and
10. removes the final minimal Firestore marker. If this last removal fails after Auth is already gone, the residual marker contains only the UID, paused state, and deletion-request timestamp and is operational cleanup work rather than an accessible member profile.

Storage deletion failures are not swallowed. If privacy-critical cleanup fails before Authentication deletion, the callable leaves the Auth identity available and the account paused so the person can authenticate again and retry rather than stranding private Storage with no recovery path.

## Deletion recovery

The client treats a `paused` account with a trusted `deletionRequestedAt` field as a deletion-recovery state, not a normal app session. Login permits that narrow state without updating normal activity data, and the session gate routes directly to a recovery screen where deletion can be retried.

A stale-recent-auth or retryable internal deletion failure signs the client out so the next login provides a fresh credential. Other non-active account states remain unavailable to the ordinary app.

This recovery path must still be exercised under staging fault injection before external beta.

## Message-history behavior today
The current implementation deletes messages **sent by the deleting user**. Messages sent by another participant are not deleted simply because the recipient account is deleted. The related conversation is deactivated, and Firestore rules deny clients access to inactive conversation metadata and messages.

This is an engineering behavior, not yet the final public retention promise. Before beta, product/privacy review must decide whether former counterpart messages should be retained, anonymized, or deleted after a defined period. The final behavior must be reflected consistently in backend cleanup, backup handling, user-facing disclosures, and support/moderation procedures.

## Account states

`active` is the ordinary usable account state.

`paused` is currently used by the trusted deletion workflow as a fail-closed recovery state. A general user-facing pause/resume account feature has **not** been finalized and must not be inferred merely from the existence of this value.

`suspended` and `banned` are reserved moderation concepts controlled only by trusted administration; operational moderation actions still require implementation/validation before release.

Deletion is not just another durable `accountStatus` value. It is a multi-system cleanup operation ending in Auth removal.

## Failure and retry expectations
Deletion is multi-system work across Firestore, Storage, and Firebase Auth. The operation is designed to fail closed by pausing the account first and preserving a fresh-auth retry path while Auth still exists.

Before external beta, staging tests must intentionally simulate:
- Firestore query/write failure;
- BulkWriter failure;
- Storage prefix deletion failure;
- Auth deletion failure;
- retry after partial cleanup;
- interruption after minimal tombstone creation;
- final Firestore tombstone deletion failure after Auth removal.

Retrying cleanup must be idempotent enough to continue deleting what remains without recreating data or restoring access.

The callable implementation is not a substitute for a production deletion job/queue if data volume later grows beyond callable execution limits. Collection sizes, Storage object counts, and timeout behavior must be reviewed before public scale.

## Retention decisions required before beta
Document explicit retention periods for:
- messages after account deletion;
- reports and moderation evidence;
- Private Vault evidence when content is reported;
- security/audit logs;
- backups;
- inactive accounts;
- failed/quarantined media;
- minimal deletion tombstones if any survive final cleanup.

These periods should be reflected in the public Privacy Policy and internal deletion implementation.

## Export/access
Before public launch, define how users can request/access a copy of their personal data. Avoid exposing other users' private data in exports.
