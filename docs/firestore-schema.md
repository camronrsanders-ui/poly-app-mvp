# Firestore Schema

## users/{uid}
- uid: string
- email: string
- createdAt: timestamp
- onboardingComplete: boolean
- lastActiveAt: timestamp
- accountStatus: string

## profiles/{uid}
- uid: string
- displayName: string
- age: integer
- city: string
- region: string
- bio: string
- headline: string
- photoUrls: array<string>
- avatarUrl: string
- genderIdentity: string
- pronouns: string
- orientation: string
- customIdentityTags: array<string>
- relationshipStructure: string
- relationshipStatus: string
- partnered: boolean
- openToConnections: boolean
- intentionTags: array<string>
- interests: array<string>
- lookingForNote: string
- ageMin: integer
- ageMax: integer
- distanceRadius: integer (5, 10, 20, 30, 50, or 100 miles; default 20)
- preferredStructures: array<string>
- preferredIntentions: array<string>
- profileVisibility: string
- mapVisibility: string
- createdAt: timestamp
- updatedAt: timestamp

## member_locations/{uid}
- uid: string
- latitude: number
- longitude: number
- accuracyMeters: number
- source: string (`device_foreground` in the app; `emulator_fixture` locally)
- observedAt: timestamp
- updatedAt: timestamp

`member_locations` is an Admin-SDK-only private collection. Firestore rules deny all direct client reads and writes, including by the document owner. Precise coordinates are accepted only through the App-Check-protected `updateDiscoverLocation` callable, used only by trusted nearby filtering, and never copied into cross-user profile views. Public city/region remains separate in `profiles`.

## _discover_sessions/{uid}
- ownerUid: string
- token: opaque random string
- radiusMiles: integer
- candidateUids: bounded array<string>
- nextIndex: integer
- createdAt: timestamp
- expiresAt: timestamp
- updatedAt: timestamp

`_discover_sessions` is an Admin-SDK-only, short-lived paging collection. Rules deny all client access. The opaque token is bound to the authenticated owner, saved radius, and server-held ordered UID pool; neither the stored document nor the client token contains precise coordinates. Starting a fresh session replaces the member's prior document, and account deletion removes the owner session and the deleted UID from other active sessions.

## relationship_cards/{autoId}
- ownerUid: string
- label: string
- connectionType: string
- displayNameOptional: string
- status: string
- note: string
- visibility: string
- sortOrder: integer
- isActive: boolean
- createdAt: timestamp
- updatedAt: timestamp

## likes/{autoId}
- fromUid: string
- toUid: string
- createdAt: timestamp

## matches/{autoId}
- userAUid: string
- userBUid: string
- createdAt: timestamp
- active: boolean

## conversations/{autoId}
- participantUids: array<string>
- createdAt: timestamp
- lastMessageAt: timestamp
- active: boolean

## messages/{autoId}
Common fields:
- conversationId: string
- senderUid: string
- text: string
- createdAt: timestamp
- isDeleted: boolean
- messageType: string
- readBy: array<string>

Ordinary chat uses `messageType: text` and is the only message shape clients may create directly under Firestore rules. The chat query explicitly filters to `messageType == text` so structured conversation artifacts do not masquerade as ordinary message bubbles.

### Shared Moments
Shared Moments intentionally reuse the conversation/message lifecycle rather than introducing a second shared datastore. Trusted App-Check-protected callables may create `messageType: shared_moment` records with:
- momentKind: `note`, `place`, or `message` in the first protected model; `photo` is reserved but blocked until protected shared-media handling is complete
- momentTitle: string
- momentNote: string
- placeLabel: string when `momentKind == place`
- sourceMessageId: string when `momentKind == message`

Saved-message moments keep only a validated reference to an existing, non-deleted text message in the same conversation; they do not duplicate the source message body into the moment document. Shared Moments never store precise coordinates. The server-side create gate remains OFF until the final UI and protected photo lifecycle are approved.

### Shared Plans
Plans also reuse the conversation/message lifecycle as `messageType: shared_plan`. The first model is intentionally manual and small:
- planTitle: string
- planNote: string
- placeLabel: optional human-readable string
- plannedFor: timestamp
- planStatus: `active` or `cancelled`
- updatedAt: timestamp
- cancelledAt: timestamp when cancelled

Plan payload validation rejects precise coordinates, calendar provider/event IDs, venue IDs, and recommendation fields. The creator owns editing and cancellation; the other participant may view the structured plan but may not modify it. Cancelled plans cannot be edited. The server-side create gate remains OFF until the structured-card UI is approved and staging validation is complete.

Because Shared Moments and Plans retain `conversationId` and `senderUid`, existing conversation closure and sender-account-deletion behavior remains authoritative. Block/unmatch makes the conversation inaccessible; account deletion removes structured artifacts authored by the deleting member through the existing sender-authored message cleanup.

## reports/{autoId}
- reporterUid: string
- reportedUid: string
- reason: string
- details: string
- createdAt: timestamp
- status: string

## blocks/{autoId}
- blockerUid: string
- blockedUid: string
- createdAt: timestamp

## Suggested enum-style values
accountStatus: active, paused, suspended, banned
profileVisibility: public, hidden, matches_only
mapVisibility: public, matches_only, private
relationship-card visibility: public, matches_only, private, unnamed_public
messageType: text, shared_moment, shared_plan (structured types are trusted-callable only; create gates currently OFF)
shared-moment kind: note, place, message, photo (photo reserved/disabled)
shared-plan status: active, cancelled
report status: open, reviewing, resolved, dismissed

Use Firebase Auth UID as the document ID for users, profiles, and private member locations. Use auto IDs for other collections unless a deterministic ID is needed to prevent duplicate logical records.
