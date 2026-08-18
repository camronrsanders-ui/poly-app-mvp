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
- conversationId: string
- senderUid: string
- text: string
- createdAt: timestamp
- isDeleted: boolean
- messageType: string
- readBy: array<string>

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
messageType: text
report status: open, reviewing, resolved, dismissed

Use Firebase Auth UID as the document ID for users, profiles, and private member locations. Use auto IDs for other collections unless a deterministic ID is needed to prevent duplicate logical records.
