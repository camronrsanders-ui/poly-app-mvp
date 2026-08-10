# Polycircle Moderation & Abuse Response Runbook

Status: engineering/operations draft. This is not a substitute for legal review, trained moderation staff, or jurisdiction-specific obligations.

## Goals

Polycircle moderation should prioritize member safety, consent, privacy, evidence integrity, and the minimum access necessary to resolve a report. Moderation actions must never depend on relationship style, gender identity, sexual orientation, consensual adult non-monogamy, or other protected/self-described identity characteristics.

## Roles

Use Firebase custom claims or an equivalent trusted administrative identity system for privileged moderation actions. Client-writable Firestore fields must never grant moderation access.

Recommended roles:
- `moderator`: may review queued reports/media and record a decision.
- `admin`: may perform moderator actions plus account-level suspension/ban/reinstatement and operational escalation.
- ordinary members: no direct access to moderation queues, evidence, internal notes, or another member's reports.

Every privileged operation should require authentication, App Check where applicable, authorization by trusted claims, bounded query/list sizes, and an audit event that excludes message bodies, intimate media, email addresses, and unnecessary profile text.

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

Profile photos are processed into a trusted, metadata-stripped representation before moderation. Moderators should review only the processed copy that is awaiting review.

Approval means only that the image passed the current content/safety review. It must not imply identity verification, relationship verification, or endorsement by Polycircle.

On rejection:
- record a short machine-safe reason code where possible;
- avoid free-text moderator notes containing sensitive personal data unless necessary;
- ensure rejected media is not available through member-facing signed URL flows;
- remove the processed object according to the approved retention policy.

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

Recommended trusted states:
- `active`: normal access.
- `paused`: member-initiated or deletion-safety hold; not discoverable/interactive.
- `suspended`: temporary moderator/admin restriction.
- `banned`: administrative enforcement state.

Clients must not be able to set these moderation states directly.

Blocking and unmatching are member safety controls, not moderation penalties. Unblocking must not automatically restore a prior match, conversation, or Private Vault grant.

## Evidence and privacy

Until final retention periods are approved:
- do not promise indefinite retention or immediate deletion of reported evidence;
- separate public/account identity from retained abuse evidence where practical;
- avoid logging report details, message text, intimate-media URLs, or protected profile-media URLs;
- use stable internal identifiers rather than copying sensitive content into logs/tickets;
- access to sensitive evidence should be auditable without recording the evidence itself in the audit event.

The final retention matrix must define at least: ordinary reports, non-consensual-content reports, protected profile media, Private Vault media, messages tied to a report, audit/security logs, backups, and appeals.

## Decision record

A moderation decision should capture structured fields such as:
- report ID;
- decision (`no_action`, `content_removed`, `warning`, `temporary_suspension`, `ban`, `escalated`);
- policy reason code;
- reviewer UID;
- decision timestamp;
- optional expiration timestamp for temporary restrictions;
- whether protected-media access was revoked/removed;
- appeal eligibility/status when an appeal process exists.

Do not place intimate content, message bodies, passwords, tokens, signed URLs, or unnecessary identity details in the decision record.

## Appeals and mistakes

Before external beta, define a simple appeal path for suspensions/bans. Reinstatement must be a trusted admin operation. Reinstatement must not silently recreate matches, likes, conversations, blocks, or private-media grants that were ended while the account was restricted.

## Incident response triggers

Escalate from ordinary moderation to security/incident response when a report suggests:
- unauthorized access to another account or protected media;
- leaked credentials/service-account material;
- a rules/backend flaw allowing cross-user reads or writes;
- signed URL lifetime/access-control failure;
- bulk scraping or enumeration;
- abuse of moderator/admin credentials.

For a suspected authorization defect, disable the affected feature or server-side gate first when feasible, preserve minimal diagnostic evidence, patch the trusted boundary, add a regression test, and only then restore access.

## Pre-beta operational checklist

Before moderators handle real member data:
- moderation claims/roles tested in staging;
- report queue built with strict server-side authorization;
- account suspension/ban/reinstatement implemented and tested;
- protected-media review queue tested end-to-end;
- Private Vault remains off unless its separate gate is fully passed;
- evidence-retention matrix approved;
- appeal/support route defined;
- audit logging reviewed for sensitive-data minimization;
- moderator access reviewed on real devices/browsers;
- incident-response owner and escalation path assigned.
