# Polycircle Backup & Recovery Plan

**Status:** design/release checklist. Production recovery claims must be validated against the actual Firebase/Google Cloud plan and configuration before external beta.

## Principles

- Backups are not a substitute for access controls or account deletion.
- Backup retention must be included in the public retention policy.
- Recovery must not resurrect deleted/blocked/private data into active product state without explicit safeguards.
- Restore testing is required; “backup enabled” alone is not a recovery plan.
- Credentials used for backup/restore must be more restricted than ordinary developer access.

## Data classes

### Firebase Authentication
Account identities/credentials are managed by Firebase Authentication. Define the production recovery strategy and what identity metadata can be restored before launch.

### Firestore
Collections include account/profile data, relationship cards, likes/passes/matches, conversations/messages, reports/blocks, protected-media metadata, request/grant state, and operational rate-limit documents.

Backup/restore scope should exclude purely ephemeral data when practical and should distinguish safety/moderation evidence from ordinary product records.

### Cloud Storage
Protected profile/private-media objects require a separate backup decision. Copying sensitive media into a second uncontrolled location increases privacy risk. Do not enable blanket media backups without an approved retention/access model.

### Source/configuration
GitHub is the source of truth for application code, rules, indexes, CI, and documentation. Production environment configuration/secrets must use an approved secrets/configuration system and must not be reconstructed from chat history or developer laptops.

## Pre-production decisions required

- Firestore backup mechanism and schedule.
- Backup region/location.
- Encryption/access controls.
- Retention duration.
- Whether deleted-user data can remain in backups, for how long, and how deletion obligations are handled.
- Whether messages/reports are included and under what retention rule.
- Whether protected media is backed up at all.
- Recovery point objective (RPO): `[REQUIRED]`.
- Recovery time objective (RTO): `[REQUIRED]`.
- Named restore approvers: `[REQUIRED]`.

## Restore safety checklist

Before restoring into any environment:

1. Confirm the target project/environment.
2. Confirm the restore snapshot timestamp and scope.
3. Confirm credentials/IAM are appropriate.
4. Prevent restored data from sending notifications or contacting real members unexpectedly.
5. Ensure blocked relationships and ended connections cannot be reactivated by stale data.
6. Ensure account-status/moderation states are not overwritten by older “active” records without review.
7. Ensure account deletions after the backup timestamp are re-applied before the restored environment is considered authoritative.
8. Ensure protected-media grants are revalidated against current block/match/request state before access.
9. Validate Firestore/Storage rules and Functions version against the restored schema.
10. Run smoke/adversarial tests before opening traffic.

## Restore drill

Before external beta, perform at least one documented staging restore drill:

- create representative staging data;
- capture backup according to the planned mechanism;
- mutate/delete representative records;
- restore into an isolated target;
- verify profile/Circle/match/message/report/media metadata integrity;
- verify deleted-account reconciliation procedure;
- run security rules tests/smoke tests;
- record elapsed restore time and failures.

Do not test destructive recovery procedures directly against the production project.

## Deletion and backups

Account deletion cleanup operates on the live authoritative data path. If backups retain deleted records temporarily, the public policy must disclose the backup retention window where required and the restore procedure must prevent deleted accounts from being silently resurrected.

A deletion ledger/tombstone strategy, if introduced, must store only the minimum information necessary for reconciliation and must have its own retention/security review.

## Incident recovery

For a security incident, see `docs/incident-response.md`. Recovery from compromise may require a known-good code/rules version, credential rotation, and data integrity review before any backup restore.

## Release gate

External beta is blocked until the production backup approach, retention, access control, and at least one restore drill are documented and accepted. This document intentionally does not claim that a production backup is currently configured.
