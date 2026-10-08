# Polycircle Private Media Vault

## Purpose
An optional 18+ private media area where an adult user can store sensitive/intimate photos and selectively share individual items with another adult user. This is not part of the public profile and must never be exposed through Discover, public profile APIs, relationship cards, analytics, notifications, logs, or public Storage URLs.

## Product name
UI working name: **Private Vault**. Avoid labels that reveal sexual content in push notifications or lock-screen previews.

## Core consent model
- Vault is opt-in and hidden by default.
- Uploading an item does not share it.
- Sharing is per recipient and per media item; no global 'all matches can see my vault' default.
- Recipient must be an active, unblocked connection/match.
- Sender can revoke access at any time.
- Blocking immediately revokes vault access in both directions.
- Unmatching/deactivating a match revokes access.
- Recipient cannot forward/share another user's vault item through Polycircle.
- No unsolicited sensitive-media attachments in normal chat. Private media uses an explicit share/request/accept flow.
- Never imply that technical controls can prevent screenshots or external capture.

## Age / account requirements
- Polycircle remains 18+.
- Private Vault requires an active authenticated account and completed onboarding.
- Before public launch, evaluate stronger age-assurance/verification requirements for sensitive-media features based on launch jurisdictions and app-store/payment policies.

## Data model
### private_media/{mediaId}
- ownerUid: string
- storagePath: string
- mediaType: `image` (MVP)
- createdAt: timestamp
- status: active | quarantined | removed
- width: integer optional
- height: integer optional
- contentHash: server-only/private optional

Client must never write moderation status or trusted processing fields.

### private_media_grants/{grantId}
Use deterministic ID `${mediaId}_${recipientUid}`.
- mediaId: string
- ownerUid: string
- recipientUid: string
- createdAt: timestamp
- revokedAt: timestamp/null
- active: boolean

Grant creation/revocation must use trusted backend functions that validate owner, recipient, active match, account state, and blocks.

### private_media_requests/{requestId} (optional UX)
- requesterUid
- recipientUid
- createdAt
- status: pending | accepted | declined | cancelled

Do not allow repeated requests to become harassment; rate limit and provide a 'do not ask again' control.

## Storage architecture
Store sensitive media separately from ordinary profile photos, e.g.:
`private_media/{ownerUid}/{mediaId}/original.jpg`

Rules should default-deny direct client reads/writes. Prefer trusted upload initialization plus short-lived authorized delivery rather than permanent public download URLs. Never store a public Firebase download URL for vault media in a readable profile document.

## Upload pipeline before beta
1. Client requests upload authorization from trusted backend.
2. Backend validates account eligibility and rate limits.
3. Upload lands in a private/quarantine path.
4. Validate file signature/MIME and size; reject unsupported formats.
5. Re-encode image and strip EXIF/GPS/metadata.
6. Run required safety/moderation checks and quarantine failures.
7. Move/mark media active only after processing.
8. Store only the protected storage path in private metadata.

## Access pipeline
1. Recipient requests a specific mediaId.
2. Trusted backend validates active grant, active match, account state, and no block in either direction.
3. Backend returns short-lived authorized access or streams/proxies content.
4. Do not cache sensitive media indefinitely on device; use protected local storage/cache policy where available.
5. Revocation must prevent future server-authorized retrieval.

## UI / privacy
- Require an explicit reveal action before displaying sensitive media.
- Blur/cover thumbnails by default.
- Do not include vault thumbnails in OS app switcher previews where platform controls permit.
- Push notifications use neutral text such as 'You received a private media share.'
- Never put media URLs, filenames, or sexual labels in analytics events.
- Provide clear delete and revoke controls.

## Safety / moderation requirements before external beta
- Report a private-media share without requiring the recipient to redistribute the file.
- Preserve moderation evidence only under a documented retention/access policy.
- Detect/handle non-consensual intimate imagery reports and illegal content through a dedicated moderation/escalation process appropriate to launch jurisdiction.
- Rate limit uploads, requests, shares, and access-token generation.
- Audit access events with minimal metadata (actor UID, media ID, timestamp, action), never image contents in ordinary logs.
- Account deletion must delete user-owned private media and revoke all grants.

## Security invariants
1. Knowing a storage path or media ID is never sufficient to view an item.
2. Public profile visibility never grants vault visibility.
3. A recipient can access only explicitly granted items.
4. A block revokes access even if a grant document still exists due to cleanup delay.
5. Client code cannot mark quarantined media active.
6. Client code cannot grant access on behalf of another owner.
7. Client code cannot alter ownerUid/recipientUid on an existing grant.
8. Sensitive media must not use permanent public URLs.

## MVP scope decision
Build the architecture and security boundaries now, but keep Private Vault behind a disabled feature flag until trusted upload processing, access-control tests, reporting/moderation flow, age-policy review, and app-store review requirements are complete.
