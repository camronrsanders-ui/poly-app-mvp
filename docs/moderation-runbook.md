# Polycircle Moderation & Abuse Response Runbook

Status: engineering/operations draft. This is not a substitute for legal review, trained moderation staff, or jurisdiction-specific obligations.

## Goals

Polycircle moderation should prioritize member safety, consent, privacy, evidence integrity, and the minimum access necessary to resolve a report. Moderation actions must never depend on relationship style, gender identity, sexual orientation, consensual adult non-monogamy, or other protected/self-described identity characteristics.

## Roles

Use Firebase custom claims or an equivalent trusted administrative identity system for privileged moderation actions. Client-writable Firestore fields must never grant moderation access.

Current trusted backend role model:
- `moderator`: may list/review report queues and review processed profile photos.
- `admin`: may perform moderator actions plus account-level suspension/ban/reinstatement.
- `superadmin`: required when an account-level action targets another privileged moderator/admin account.
- ordinary members: no direct access to moderation queues, evidence, internal notes, or another member's reports.

Current backend protections include App Check, trusted custom-claim checks, bounded queue sizes, per-actor rate limits, backend-only internal moderation collections, and default-deny Firestore client access. These controls still require staging validation and an operator-facing moderation interface/process before real-member use.

## Implemented trusted moderation callables

### Report queue
`listModerationReports`:
- requires moderator/admin/superadmin claim;
- limits queue state to supported moderation statuses;
- bounds each response;
- returns report data and internal reviewer notes only to trusted moderators.

`reviewModerationReport`:
- records the user-visible report status/review timestamp on the report;
- stores reviewer UID and internal note separately in backend-only `report_moderation` so a reporting member cannot directly read staff identity/notes through Firestore.

### Profile-photo queue
`listProfilePhotosForReview` provides a bounded moderator-only list of photos in `processed_pending_review` and issues short-lived preview URLs only after trusted role checks. `reviewProfilePhoto` performs the final approve/reject transition. This still needs staging/real operational validation before moderators handle real member photos.

### Account state
`setAccountModerationState` is admin-only and can set `active`, `suspended`, or `banned` with a structured reason. A non-superadmin cannot target an account carrying moderator/admin/superadmin claims.

The account state is changed first so Firestore rules and ordinary callables fail closed immediately. A ban additionally:
- disables the Firebase Auth user;
- deletes incoming/outgoing likes;
- closes active matches and conversations without falsifying `lastMessageAt`;
- revokes Private Vault grants;
- cancels Private Vault requests.

Reinstatement does **not** recreate likes, matches, conversations, or private-media permissions ended by a ban. A pending account-deletion state cannot be overwritten by moderation state changes.

`account_moderation` stores current internal account-action metadata and `moderation_audit` records minimal action history. These collections are not directly client-accessible. Their retention period still requires approval.

## Report intake

Current trusted report reasons include harassment, fake profile, hate speech, misrepresentation, spam, non-consensual content, and other.

At intake:
1. Validate the reporter and target IDs server-side.
2. Rate-limit report creation before expensive lookups.
3. Store the report through the trusted backend, not direct client writes.
4. Keep reports unreadable to the reported member.
5. Do not automatically tell the reported person who submitted the report.
6. Preserve only the details needed for review.

A member should always be able to block another member independently of whether a moderator has reviewed the report.

## Severity triage

### P0 — immediate safety/privacy risk
Examples: suspected non-consensual intimate imagery, credible threats of violence, child sexual abuse material indicators, doxxing with imminent risk, or evidence of account compromise affecting protected media.

Actions:
- restrict further access/sharing immediately when technically safe to do so;
- preserve only the evidence required by the approved retention/legal process;
- escalate to an authorized administrator;
- do not redistribute or download intimate evidence outside the approved moderation environment;
- follow applicable mandatory reporting/legal procedures once defined and reviewed.

### P1 — serious abuse
Examples: repeated harassment, hate speech, impersonation/fraud, repeated consent violations, ban evasion.

Actions:
- review promptly;
- consider temporary suspension while investigation is active when continued access creates meaningful risk;
- document the specific policy basis for the decision;
- revoke connection/private-media access when relevant.

### P2 — ordinary policy enforcement
Examples: spam, misleading profile information, lower-severity conduct issues.

Actions:
- review in queue order subject to recurrence/severity;
- warn, remove content, restrict features, or suspend as appropriate;
- avoid collecting extra evidence merely because it is available.

## Protected profile-media review

Profile photos are processed into a trusted, re-encoded representation before moderation. Moderators should review only the processed copy that is awaiting review.

Approval means only that the image passed the current content/safety review. It must not imply identity verification, relationship verification, or endorsement by Polycircle.

On rejection:
- record a short machine-safe reason code where possible;
- avoid free-text moderator notes containing sensitive personal data unless necessary;
- ensure rejected media is not available through member-facing signed URL flows;
- remove the processed object according to the approved retention policy.

The queue/list and review callables are implemented, but staging validation, moderator UI/workstation controls, reason taxonomy, staffing procedures, and final retention rules remain release blockers.

## Private Vault moderation

Private Vault must remain disabled until its complete policy, moderation, evidence-retention, and operational controls are validated.

When eventually enabled:
- intimate media must never enter a general public moderation gallery;
- access should be case-scoped and role-restricted;
- moderators should receive the minimum media/context required to adjudicate the specific report;
- opening sensitive evidence should be an explicit action, not an automatic thumbnail reveal;
- evidence views should use short-lived authorized delivery and should not create permanent shareable URLs;
- grants must never override a block, ended connection, withdrawn request/consent, removed media, account suspension, or moderation hold;
- reported media must not be destructively deleted until the final evidence-retention rule determines whether it must be preserved for a limited period.

Screenshots or external-camera capture cannot be guaranteed to be prevented. Product copy must not promise screenshot-proof media.

## Account actions

Trusted states:
- `active`: normal access.
- `paused`: deletion-safety/recovery state in the current implementation; it is not yet a generalized member pause feature.
- `suspended`: administrative restriction. The Firebase Auth identity may still authenticate, but app routing, Firestore rules, and trusted callables deny ordinary product use.
- `banned`: administrative enforcement state; Firebase Auth is disabled and interaction state is terminated.

Clients cannot set these moderation states directly.

Blocking and unmatching are member safety controls, not moderation penalties. Unblocking must not automatically restore a prior match, conversation, or Private Vault grant.

## Evidence and privacy

Until final retention periods are approved:
- do not promise indefinite retention or immediate deletion of reported evidence;
- separate public/account identity from retained abuse evidence where practical;
- avoid logging report details, message text, intimate-media URLs, or protected profile-media URLs;
- use stable internal identifiers rather than copying sensitive content into logs/tickets;
- access to sensitive evidence should be auditable without recording the evidence itself in the audit event.

The final retention matrix must define at least: ordinary reports, non-consensual-content reports, protected profile media, Private Vault media, messages tied to a report, moderation/audit/security logs, backups, and appeals.

## Decision record

A moderation decision should capture structured fields such as:
- report ID;
- decision/status;
- policy reason code;
- reviewer UID in an internal-only record;
- decision timestamp;
- optional expiration timestamp for temporary restrictions when that feature is added;
- whether protected-media access was revoked/removed;
- appeal eligibility/status when an appeal process exists.

Do not place intimate content, message bodies, passwords, tokens, signed URLs, or unnecessary identity details in the decision record.

## Appeals and mistakes

Before external beta, define a support/appeal intake path for suspensions/bans. Reinstatement is implemented as a trusted admin state transition, but the human appeal process is not yet complete. Reinstatement must not silently recreate matches, likes, conversations, blocks, or private-media grants that were ended while the account was restricted.

## Incident response triggers

Escalate from ordinary moderation to security/incident response when a report suggests:
- unauthorized access to another account or protected media;
- leaked credentials/service-account material;
- a rules/backend flaw allowing cross-user reads or writes;
- signed URL lifetime/access-control failure;
- bulk scraping or enumeration;
- abuse of moderator/admin credentials.

For a suspected authorization defect, disable the affected feature or server-side gate first when feasible, preserve minimal diagnostic evidence, patch the trusted boundary, add a regression test, and only then restore access. See `docs/incident-response.md`.

## Pre-beta operational checklist

Before moderators handle real member data:
- moderator/admin/superadmin claim assignment and revocation tested in staging;
- report queue callables validated against deployed App Check endpoints;
- account suspension/ban/reinstatement fault-tested end-to-end;
- privileged-target protection tested;
- protected profile-media review queue tested end-to-end;
- operator-facing moderator UI/workstation procedure built and access-reviewed;
- Private Vault remains off unless its separate gate is fully passed;
- evidence-retention matrix approved;
- appeal/support route defined;
- audit logging reviewed for sensitive-data minimization and retention;
- moderator access reviewed on real devices/browsers;
- incident-response owner and escalation path assigned.
