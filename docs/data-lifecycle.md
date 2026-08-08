# Polycircle Data Lifecycle & Account Deletion

Privacy is a release requirement.

## Principles
- Collect only data needed for the product.
- Do not store exact location by default; use coarse city/region for MVP.
- Do not expose private relationship-card information in analytics/logs.
- Do not log message bodies, report details, email addresses, or private identity fields in application analytics.
- Relationship names typed by a user are unverified private user-generated content and must never imply the named person's consent.

## Account deletion design
Account deletion must be a trusted backend operation, not a client-side series of deletions.

Before external beta, implement a callable `deleteMyAccount` function that:
1. re-validates the authenticated user and, for sensitive deletion, supports recent-auth requirements;
2. immediately makes the account non-discoverable;
3. removes or tombstones the user's public profile;
4. deletes user-owned relationship cards;
5. deletes outgoing likes and invalidates active matches/conversations;
6. removes user-owned profile media from Storage;
7. deletes blocks created by the user and safely handles incoming block references;
8. deletes or anonymizes messages according to the final retention/privacy policy;
9. preserves abuse reports only when legally/safety-justified and separates them from public identity where practical;
10. deletes the Firebase Auth account last, after required cleanup succeeds;
11. records only minimal operational/audit evidence needed to confirm deletion, without retaining sensitive profile content.

## Deactivation vs deletion
`paused` is reversible and hides the user from discovery while retaining account data.
`deleted` must not simply be another accountStatus value. Deletion requires the trusted cleanup workflow above.
`suspended` and `banned` are moderation states controlled only by trusted administration.

## Retention decisions required before beta
Document explicit retention periods for:
- messages after account deletion;
- reports and moderation evidence;
- security/audit logs;
- backups;
- inactive accounts.

These periods should be reflected in the public Privacy Policy and internal deletion implementation.

## Export/access
Before public launch, define how users can request/access a copy of their personal data. Avoid exposing other users' private data in exports.
