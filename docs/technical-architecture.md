# Polycircle — Technical Architecture

## Target Platform
Mobile-first Flutter application for iOS and Android, with future web compatibility.

## Backend
Firebase services:
- Firebase Authentication
- Cloud Firestore
- Firebase Storage for profile media when enabled
- Firebase Cloud Messaging later
- Cloud Functions or equivalent trusted server-side logic when client trust is insufficient

## Recommended Application Layers
- `features/auth/`
- `features/onboarding/`
- `features/profile/`
- `features/circle/`
- `features/discover/`
- `features/matches/`
- `features/messages/`
- `features/safety/`
- `core/models/`
- `core/services/`
- `core/theme/`
- `core/widgets/`
- `core/utils/`

Actual implementation may adapt to the chosen Flutter architecture, but avoid giant files and hard coupling.

## Data Ownership
`users/{uid}` and `profiles/{uid}` use Firebase Auth UID as document ID.
Other collections may use auto IDs unless deterministic IDs improve consistency.

## Trusted Logic Candidates
Consider trusted/server-side implementation for:
- canonical mutual match creation
- moderation/admin account status changes
- notification fan-out
- future verification
- any logic involving private server credentials

## Matching Canonicalization
For two user UIDs A and B, use a canonical ordering (e.g. lexicographic sort) to derive a pair key. This prevents A+B and B+A from becoming different logical matches.

## Messaging
MVP supports one-to-one conversations for connected users.
Conversation membership must be checked in Firestore rules. Messages must require membership in their conversation.

## Privacy Enforcement
Never rely on UI hiding alone. Security rules and queries must enforce ownership and authorized reads.

## Performance
- paginate Discover results
- paginate message history
- limit live listeners
- compress/resize images before large uploads where practical
- query only fields/documents needed
- create required Firestore composite indexes

## Environment & Secrets
Firebase client app configuration may exist in the client as required by Firebase SDKs, but admin/service-account credentials and private API secrets must never be committed.
Use environment/config mechanisms appropriate to the app and backend.

## Development Quality Gates
Before merge/release:
- `flutter pub get`
- formatter
- `flutter analyze`
- tests
- platform build/run where environment allows
- verify Firestore rules
- end-to-end acceptance flow from the product specification