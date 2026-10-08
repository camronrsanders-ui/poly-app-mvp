# Polycircle Abuse & Threat Model

## Highest-risk abuse cases

### Account / identity abuse
- credential stuffing and automated signup;
- impersonation / fake profiles;
- ban evasion;
- scraping profiles for identity or location data;
- outing users or correlating private identity data.

Controls: Firebase Auth protections, App Check, rate limits, verification options later, coarse location, least-privilege reads, moderation tools, no public bulk profile API.

### Harassment / unwanted contact
- repeated likes/messages;
- contacting a user after a block;
- creating alternate accounts to bypass a block;
- coercion, threats, hate speech.

Controls: block enforced server-side, report workflow, rate limits, account moderation, safety UI reachable from profile/chat, future device/risk signals subject to privacy review.

### Relationship/privacy abuse
- naming a partner without consent;
- exposing another person's relationship structure;
- using a relationship map to infer sensitive relationships;
- screenshots/off-platform sharing cannot be technically prevented.

Controls: relationship-card privacy, unnamed-public mode, no implied verification, future mutual confirmation for linked accounts, privacy education, conservative map defaults.

### Messaging abuse
- spam/flooding;
- malicious links;
- oversized payloads;
- unauthorized conversation reads;
- message modification.

Controls: matched-only conversations, block checks, length/type validation, immutable sender/content, rate limits before beta, optional link-safety measures later, no message bodies in analytics.

### Backend abuse
- forged client writes;
- race conditions creating duplicate matches/conversations;
- direct Firestore requests bypassing UI;
- replay/automation against callable functions.

Controls: trusted Cloud Functions for sensitive transitions, deterministic IDs, transactions, Firestore rules, App Check, emulator adversarial tests, server-side rate limiting.

### Media abuse
- non-image uploads;
- oversized files;
- malicious content;
- metadata/location leakage;
- unauthorized reads.

Controls: Storage ownership rules, MIME/size validation, authenticated delivery, image processing/metadata stripping before beta, reporting/moderation pipeline, no public bucket listing.

## Security invariants
1. A user must never gain write authority by changing a UID in a request.
2. A blocked pair must not regain contact through direct document IDs.
3. A match requires reciprocal intent and trusted validation.
4. A conversation requires an active match and trusted validation.
5. Moderation status is never client-controlled.
6. Private/matches-only relationship information is never treated as public because another field is public.
7. Sensitive logs must not contain message bodies or private relationship details.
8. Every external-beta release must pass negative authorization tests, not only happy-path UI tests.
