# Polycircle adversarial readiness review

This document records a hostile-review pass over the current Polycircle foundation. The goal is not to certify the app as secure or launch-ready; it is to make the remaining trust assumptions, residual risks, and release gates explicit enough that engineering, product, safety, and privacy reviewers can challenge them before external distribution.

## Review posture

Assume an attacker can:

- modify the Flutter client and call Firebase endpoints directly;
- replay or race legitimate requests;
- control all ordinary profile, message, relationship-card, and request text they are allowed to submit;
- try arbitrary target UIDs and document IDs;
- operate many accounts and generate high request volume;
- deliberately upload malformed or oversized images;
- retain any signed media URL already issued to their device until it expires;
- screenshot or externally photograph anything displayed on their screen;
- exploit stale local application state after blocking, suspension, deletion, or feature shutdown;
- attempt to infer private preferences, incoming Likes, reports, moderation state, Circle notes, or protected media metadata.

Do not assume the distributed client is trustworthy. Firebase Security Rules, trusted callable Functions, App Check, Auth state, and backend-owned documents are the enforcement boundaries.

## Controls verified in source and automated tests

### Identity and account state

- Account bootstrap uses a minimal Firestore account schema and rolls a newly created Auth identity back if bootstrap fails.
- Client writes cannot assign roles, moderation fields, or account states.
- Account status is enforced in Firestore Rules and trusted Functions.
- The Flutter session gate watches the trusted account document continuously so suspension, ban, and deletion-pending state remove normal app access without requiring a restart.
- Account deletion requires an explicit `DELETE` confirmation, recent authentication, App Check, a durable paused state, retryable cleanup, and Auth deletion only after privacy-critical Storage cleanup.

### Discovery and matching

- Full profile documents remain owner-only.
- Discovery returns a sanitized allowlisted profile view from trusted Functions.
- Private discovery preferences are applied reciprocally in trusted code.
- Like authorization reads caller/target account state, target visibility, block state, reverse Like, prior Pass, and match state in the same Firestore transaction as Like/Match writes.
- Pass reads opposing Like and connection history in its transaction so concurrent explicit Like/Pass actions cannot leave contradictory state.
- Ended connections do not silently reappear in Discover or restart through the ordinary Like flow.

### Conversations and messages

- Conversation creation reads both accounts, block state, match state, and existing conversation state in the same transaction as creation.
- The client does not broad-query the conversations collection; trusted connection views provide active conversation metadata.
- A message and its conversation activity pointer are committed in one Firestore batch.
- Security Rules require `lastMessageAt` and `lastMessageId` to point to the exact same-batch message created by the authenticated participant. A modified client cannot manufacture chat activity by bumping a timestamp without creating an authorized message.
- Message timestamps are server-authoritative.
- Read receipts are monotonic and only the authenticated reader may add their own UID; a sender cannot mark the other participant as having read a message.
- Blocking, unmatching, account deletion, and moderation closure do not rewrite `lastMessageAt` and therefore do not fabricate message chronology.

### Circle privacy

- Full relationship-card documents are readable only by the active owner.
- Other members use a trusted Circle view that enforces global/card visibility and redacts optional names and free-text notes for unnamed-public cards.
- Card timestamps are server-authoritative and unknown privileged fields are rejected.
- A named person in a card is never treated as a verified account relationship or proof of consent.

### Profile media

- Direct client Storage SDK access is denied.
- Uploads use short-lived signed write URLs into quarantine.
- Uploaded type/size is validated and the image is decoded/re-encoded by trusted processing before moderation.
- Re-encoding removes original image metadata and caps decoded pixel count/output dimensions.
- Only the trusted processed JPEG path can be approved or delivered.
- Cross-user delivery requires current profile visibility/account/block authorization and uses short-lived signed read URLs.
- Moderation queues expose protected previews rather than raw Storage paths.
- Profile-media callables have abuse budgets and their rate-limit state is included in account deletion cleanup.

### Private Vault

The Private Vault remains disabled in both Flutter and trusted backend feature gates. It must stay disabled for external users until every release gate below is completed.

The backend foundation nevertheless treats consent as a live authorization state rather than a one-time event:

- request, response, grant, access, listing, cancellation, revocation, upload, processing, review, and reporting paths use trusted Functions;
- new sharing requires an active match, no block, active accounts, an accepted recipient request, approved media, and an explicit per-recipient grant;
- grant creation re-reads current pair state, accepted request, media state, and grant state in the same transaction as the grant write;
- access requires both a still-active grant and a still-accepted request;
- recipient cancellation changes the accepted request to `cancelled` first, making consent withdrawal authoritative immediately, then exhaustively revokes active grants for that exact pair;
- owner revocation and recipient cancellation remain safety-reductive operations even during a Vault kill-switch event;
- reporting remains available during a Vault kill-switch event and does not return media bytes;
- block/unmatch/ban cleanup revokes grants and cancels requests;
- Storage-triggered Vault processing honors the server kill switch, so a previously issued upload URL cannot bypass a later shutdown;
- listings batch authorization and consent reads and expose only minimal safe metadata.

### Moderation and abuse response

- Moderation callables require App Check, trusted custom claims, and an active staff account.
- Moderator notes live outside reporter-readable report documents.
- Privileged targets require super-administrator authority for account-state changes.
- Restrictive account-state transitions fail closed across Firestore/Auth ordering.
- A ban closes active matches/conversations and revokes/cancels private-media access state without fabricating chat activity.
- Staff actions are recorded in backend-only moderation state/audit collections.

### Local data and supply chain

- Native Firestore disk persistence is disabled so relationship/chat/profile documents are not intentionally retained in the SDK's persistent disk cache across signed-in users on the same device.
- Real Firebase client configuration and signing/key files are excluded from git.
- A repository static scan fails CI for committed secret/key markers, App Check debug material in runtime source, or direct Firebase Storage client SDK usage.
- CI actions are pinned to exact commit SHAs.
- Dependency auditing fails on high/critical production advisories, and Dependabot is configured for Flutter, Functions, security-test dependencies, and GitHub Actions.

## Residual risks that are not solved by source hardening alone

### Short-lived URL revocation window

A signed media URL already delivered to a device remains a bearer capability until its approximately two-minute expiry even if a block or revocation happens immediately afterward. Eliminating that residual window would require a different delivery architecture, such as an authenticated proxy/token exchange checked on every media fetch. Do not describe signed URLs as instant revocation.

### Screenshots and external capture

The app cannot guarantee that displayed content will not be screenshotted, screen-recorded, photographed by another device, or copied after display. Private Vault UX and policy must state this plainly.

### Client text and social abuse

Schema/rate controls cannot determine whether ordinary text is deceptive, coercive, hateful, threatening, or personally identifying. Human moderation, reporting operations, escalation procedures, and policy enforcement remain required.

### Self-attested age

The current 18+ product rule is not equivalent to robust identity/age verification. Before enabling intimate-media features, product/legal/safety must decide whether stronger age assurance is required in target jurisdictions and app stores.

### Email ownership

Email/password Auth does not by itself prove a user controls a socially meaningful identity. Before public launch, decide whether verified email is mandatory and test the complete verification/recovery flow. Do not silently add a launch-time verification requirement without validating emulator, staging, and account-recovery UX.

### Local display caches outside Firestore

Disabling Firestore disk persistence does not eliminate transient in-memory image/widget caches, operating-system screenshots, device backups, or content copied outside the app. Real-device privacy testing must include logout/account-switch behavior and protected-image teardown.

### Historical data and retention

Account deletion intentionally preserves or anonymizes some shared/history/moderation records rather than blindly deleting every document. Final message, report, moderation, audit, and backup retention periods require an approved privacy/legal decision and end-to-end deletion testing.

### Large-account cleanup and moderation operations

Some administrative cleanup paths still perform broad backend queries. They fail closed for authorization but need staging load/fault testing, resumability, monitoring, and operator tooling before production scale.

### UID-derived document keys

Several pair/rate-limit document IDs derive from Firebase Auth UIDs. Current email/password-created Firebase UIDs fit the expected application path, but adding imported/custom identity providers requires a documented UID encoding/migration strategy before those providers are enabled.

## External beta release gates

Do not call Polycircle externally beta-ready until all of the following are completed or explicitly risk-accepted by the accountable owner:

1. Create a real staging Firebase project capable of deploying the Cloud Functions runtime.
2. Deploy Functions, Firestore Rules, Storage Rules, and indexes to staging.
3. Validate App Check enforcement against deployed staging endpoints; debug-token registration is not production validation.
4. Run complete iOS and Android flows on real devices, including reinstall, logout/login, account switching, poor connectivity, background/foreground transitions, clock changes, and interrupted writes.
5. Exercise two-account adversarial flows: simultaneous Like/Pass, Like/block, conversation/block, send/unmatch, report/block, deletion during messaging, and account suspension while screens are open.
6. Fault-inject account deletion at Firestore, Storage, and Auth boundaries and confirm retries finish without resurrecting user-visible data.
7. Validate profile-photo upload, quarantine, processing, moderation, rejection, delivery, deletion, block, and signed-URL expiry with real Cloud Storage.
8. Build actual moderator/admin operations with least-privilege credentials, audit access, queue monitoring, and incident escalation; source callables alone are not an operations program.
9. Run accessibility testing with VoiceOver and TalkBack plus large text, reduced motion, contrast, focus order, and error announcements.
10. Run performance/read-cost/load tests for discovery, connection lists, messages, moderation, deletion, and media processing at realistic cardinalities.
11. Complete backup/restore drills and verify that backup retention matches privacy disclosures and deletion commitments.
12. Finalize Terms, Privacy Policy, Community Guidelines, data-retention disclosures, intimate-media policy, reporting/appeals process, and app-store safety/compliance requirements.
13. Make and test the email-verification and stronger age-assurance decisions.
14. Keep Private Vault client/server gates OFF until its dedicated moderation, retention, evidence handling, real-device privacy, and legal/app-store gates pass.
15. Perform a final independent security/privacy review on the deployed staging build, not only the source tree.

## Rule for future feature work

Any feature that creates a new cross-user write, reveals another user's data, changes a connection state, delivers protected media, changes account/moderation state, or weakens a privacy default must ship with:

- an explicit trust-boundary decision;
- an abuse/race-condition review;
- server-authoritative timestamps where chronology matters;
- App Check and account-state enforcement for trusted endpoints;
- bounded reads/writes and a rate/abuse budget where appropriate;
- adversarial tests for modified-client behavior;
- deletion/retention impact review;
- a fail-closed response to malformed/legacy data;
- staging and real-device acceptance criteria.

Passing CI is necessary, not sufficient, for launch readiness.
