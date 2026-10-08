# Polycircle Security Review Checklist

Security and user safety are release blockers, not optional polish.

## Authentication and account state
- Require Firebase Authentication for private application data.
- Do not trust UID, email, accountStatus, role, or ownership values supplied by the client when they can be derived from auth/server state.
- Suspended/banned users must not participate in discovery, likes, new matches, or messaging.
- Never ship service-account credentials, admin SDK secrets, private keys, or signing secrets in the client or repository.

## Authorization / IDOR
For every collection, test both the allowed owner/participant and an unrelated authenticated user.
- users: self only.
- profiles: owner writes; reads according to visibility/block/account state.
- relationship_cards: owner writes; reads according to card visibility plus profile/block rules.
- likes: sender creates/deletes; involved users only read.
- matches: participants only; creation requires reciprocal likes and no block.
- conversations/messages: active participants only; new conversation requires active match and no block.
- reports: reporter can create/read own report; moderation writes must be server/admin only.
- blocks: blocker manages own block; do not expose a user's block list to unrelated users.

## Blocking
Blocking must be enforced at the authorization layer, not only hidden in UI queries.
After A blocks B, verify:
- neither appears in the other's Discover results;
- no new like or match can be created;
- no new conversation can be created;
- existing conversation cannot send/read new content according to product policy;
- relationship cards and non-public/private data are not leaked;
- direct document-ID access does not bypass the block.

## Matching and conversation integrity
- Use canonical deterministic pair IDs for 1:1 matches/conversations.
- Prevent self-like, self-match, self-conversation.
- Prevent duplicate match and duplicate 1:1 conversation.
- Prefer trusted backend/Cloud Function transaction for production match creation so client races cannot create inconsistent state.

## Input/content safety
- Validate lengths and types for bios, messages, notes, names, reports, custom identity labels.
- Add server-side abuse/rate controls before public launch.
- Escape/render user-generated text as text, never executable markup.
- Restrict uploads by MIME type, size, ownership path, and authorization.
- Strip unnecessary image metadata before/while processing uploads when practical.

## Privacy
- Location should not expose exact coordinates by default. MVP stores coarse city/region unless precise location is explicitly required later.
- Respect profileVisibility and mapVisibility everywhere, including direct reads.
- Individual relationship-card privacy must override broader map/profile visibility.
- A typed relationship-card name must never imply consent from or expose a linked real person.
- Define data deletion/account deletion before public launch.

## Firestore rules testing
Use Firebase Emulator Suite and automated rules tests before production deployment. Minimum adversarial tests:
1. unauthenticated reads/writes;
2. unrelated authenticated user reads/writes;
3. owner/participant valid access;
4. forged ownerUid/senderUid/participantUids;
5. blocked pair attempts;
6. match without reciprocal likes;
7. conversation without match;
8. message to unrelated conversation;
9. attempts to rewrite another user's message;
10. attempts to modify report status from client;
11. hidden/private profile/card direct-ID reads;
12. suspended/banned account interactions.

## Production controls before external beta
- Firebase App Check.
- Crash reporting and security-relevant audit logging without sensitive message contents.
- Rate limiting / anti-spam controls.
- Abuse-report moderation workflow.
- Account deletion and data-retention policy.
- Privacy policy and Terms/Community Guidelines.
- Dependency/security scanning in CI.
- Secret scanning and branch protection on main.
- Backup/recovery strategy for Firestore configuration and rules.

## Release rule
Do not merge/deploy solely because UI works. A security-sensitive feature is complete only when its Firestore rules, negative authorization tests, and block/privacy behavior have been verified in the emulator or equivalent test environment.
