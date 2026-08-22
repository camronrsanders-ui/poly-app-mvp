# Polycircle Data Retention Matrix — Draft

Status: engineering/privacy decision tracker. Durations marked `TBD` must be approved before external beta and reflected consistently in backend behavior, backups, support procedures, and public disclosures.

| Data class | Current behavior | Access boundary | Final duration | Deletion / expiry action | Beta decision needed |
|---|---|---|---|---|---|
| Account/Auth identity | Active until trusted account deletion succeeds | Authenticated account / trusted backend | User-controlled + TBD inactive-account policy | Delete Firebase Auth identity last | Define inactive-account policy |
| User account document | Removed during trusted account deletion | Owner direct read; trusted backend writes privileged state | Account lifetime | Delete after dependent cleanup | Validate partial-failure retry |
| Full profile | Removed during trusted account deletion | Owner-only direct Firestore read; sanitized trusted views for others | Account lifetime | Delete document | Confirm backups behavior |
| Private Discover location | Replaced by occasional foreground Discover updates; removed during trusted account deletion | Admin/trusted backend only; never included in cross-user profile views | Current implementation accepts records updated within 30 days; final retention/expiry TBD | Delete on account deletion; add automated stale-record expiry before scale | Approve maximum storage age and backup expiry |
| Relationship cards | Removed during trusted account deletion | Owner-only direct read; trusted redacted view when shared | Account lifetime | Delete owner cards | Confirm backup expiry |
| Likes | Both directions removed on block/unmatch/deletion where applicable | Sender read only; trusted backend writes | Connection-state dependent | Delete | Define stale-like cleanup policy |
| Pass state | Removed on explicit later Like or account deletion | Backend-only | Until reversed/deleted | Delete | Define optional stale-pass expiry |
| Active match | Deactivated on block/unmatch/deletion | Participants may read only while active | Connection lifetime | Retain backend-only ended record for reconnect/history integrity | Decide eventual historical retention |
| Conversation metadata | Deactivated on block/unmatch/deletion | Participants while active; backend after closure | TBD | Preserve chronology; later delete/anonymize per policy | Decide closed-conversation retention |
| Message sent by deleting member | Currently deleted during account deletion | Active conversation participants only | Current: until sender deletion / otherwise TBD | Delete sender-authored message | Finalize message retention |
| Message sent by other member | Currently retained when recipient deletes account but becomes inaccessible through inactive conversation | Active conversation participants only | TBD | Retain, anonymize, or delete after approved period | **Required before beta** |
| Shared Moment | Create path currently server-gated OFF; modeled as a specialized conversation message so block/unmatch closes access and sender deletion removes creator-authored moments | Active compliant conversation participants through trusted callables; direct client creation denied | TBD, aligned with conversation/message policy | Delete creator-authored moment on creator deletion; counterpart-authored retained moment becomes inaccessible pending final policy | **Required before enabling Shared Moments** |
| Block record | Removed when blocker unblocks or account deletion cleans references | Blocker direct read; trusted backend writes | Until unblock/deletion | Delete | Decide whether internal abuse history needs separate record |
| Ordinary abuse report | Retained and identity-anonymized on account deletion | Reporter read; moderator/admin trusted access when built | TBD | Anonymize/delete after approved safety period | **Required before beta** |
| Non-consensual-content report/evidence | Retention behavior not finalized | Strict case-scoped moderator/admin access | TBD | Preserve only if justified, then securely remove | **Required before Private Vault/beta** |
| Profile photo quarantine object | Deleted after processing/rejection where workflow succeeds | No direct client Storage access | Short operational window; exact TTL TBD | Delete quarantine object | Add orphan cleanup/TTL process |
| Processed approved profile photo | Deleted by owner/account deletion or moderation removal | Short-lived signed URL after trusted authorization | Account/media lifetime | Delete protected object + metadata | Define cache/backups expiry |
| Rejected profile photo | Processed object removed on rejection; metadata may remain | Backend-only metadata | TBD | Remove object; expire minimal decision metadata | Define moderation retention |
| Private Vault quarantine | Feature disabled; pipeline design removes/controls quarantine | Backend-only | TBD | Secure deletion after processing/failure period | **Required before enablement** |
| Private Vault active media | Feature disabled | Explicit consent/grant + active match + trusted short-lived delivery | TBD | Owner removal/account deletion/policy action | **Required before enablement** |
| Private Vault grants/requests | Revoked/cancelled on block/unmatch; deleted on account deletion | Backend-only | Connection/media dependent | Revoke or delete | Define historical consent-audit retention |
| Rate-limit documents | Per-user action counters; cleaned on account deletion | Backend-only | Short operational windows | Delete on account deletion; optional TTL later | Define automated TTL cleanup |
| Security/audit events | Production audit store not finalized | Restricted operations/security access | TBD | Redact/expire according to security need | **Required before beta** |
| Crash/error telemetry | Not yet finalized | Operations only | TBD | Aggregate/redact/expire | Ensure no sensitive payload logging |
| Backups | Production strategy not finalized | Restricted infrastructure access | TBD | Expire on documented schedule; deletion propagates on restore procedure | **Required before beta** |

## Rules for choosing final durations

The final retention policy should use the shortest period that still serves a defined safety, security, operational, contractual, or legal need. "We might need it later" is not a sufficient retention purpose.

For every retained class, document:
- why it is retained;
- who can access it;
- the trigger that starts the retention clock;
- the exact deletion/anonymization action;
- how backups are handled;
- whether a user-facing export can include it without exposing another person's private data.

## Account deletion consistency check

Before beta, the approved matrix must be compared directly against `deleteMyAccount`, Storage cleanup prefixes, moderator workflows, backup/restore procedures, and user-facing deletion copy. Any mismatch is a release blocker.

## Private Vault gate

No Private Vault duration should be treated as approved merely because an engineering value exists. The feature remains disabled until sensitive-media retention, report evidence, consent withdrawal, owner deletion, account deletion, and moderator access are reviewed together and tested end-to-end.
