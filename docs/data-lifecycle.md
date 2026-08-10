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
3. deactivates matches and conversations that include the account;
4. deletes message documents sent by the deleting user;
5. anonymizes the deleting user's identity in retained report documents rather than exposing the deleted UID as the reporter/reported account;
6. deletes the user's profile document;
7. deletes protected profile-media and Private Vault Storage prefixes, including quarantine prefixes;
8. deletes the Firestore user record; and
9. deletes the Firebase Auth identity last.

The Auth identity is intentionally deleted last. A cleanup failure should not leave a successfully deleted Auth identity while account-owned application data remains unprocessed.

## Message-history behavior today
The current implementation deletes messages **sent by the deleting user**. Messages sent by another participant are not deleted simply because the recipient account is deleted. The related conversation is deactivated, and Firestore rules deny clients access to inactive conversation metadata and messages.

This is an engineering behavior, not yet the final public retention promise. Before beta, product/privacy review must decide whether former counterpart messages should be retained, anonymized, or deleted after a defined period. The final behavior must be reflected consistently in backend cleanup, backup handling, user-facing disclosures, and support/moderation procedures.

## Deactivation vs deletion
`paused` is reversible and hides the user from active product flows while retaining account data.
`deleted` must not simply be another `accountStatus` value. Deletion requires the trusted cleanup workflow above.
`suspended` and `banned` are moderation states controlled only by trusted administration.

## Failure and retry expectations
Deletion is multi-system work across Firestore, Storage, and Firebase Auth. The operation is designed to fail closed by pausing the account first. Before external beta, staging tests must intentionally simulate partial failures and verify that retrying cleanup is safe and does not recreate data or restore access.

The current implementation is not a substitute for a production deletion job/queue if data volume later grows beyond callable execution limits. Collection sizes, Storage object counts, and timeout behavior must be reviewed before public scale.

## Retention decisions required before beta
Document explicit retention periods for:
- messages after account deletion;
- reports and moderation evidence;
- Private Vault evidence when content is reported;
- security/audit logs;
- backups;
- inactive accounts;
- failed/quarantined media.

These periods should be reflected in the public Privacy Policy and internal deletion implementation.

## Export/access
Before public launch, define how users can request/access a copy of their personal data. Avoid exposing other users' private data in exports.
