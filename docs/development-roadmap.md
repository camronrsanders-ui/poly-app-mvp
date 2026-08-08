# Polycircle — Development Roadmap

## Phase 0 — Foundation
- Create clean Flutter project if no working app exists.
- Confirm iOS/Android targets.
- Add Firebase configuration.
- Add theme/brand foundation.
- Add routing and protected-route behavior.
- Add environment/secrets strategy.
- Add baseline tests and analysis configuration.

## Phase 1 — Authentication
- Email/password signup
- Login
- Logout
- Password reset
- Persistent auth state
- Create users/{uid}
- Route incomplete users to onboarding

Exit criteria: a new account can be created, logged out, and logged back in with correct routing.

## Phase 2 — Onboarding & Profile
- Multi-step onboarding
- Identity/pronouns/orientation
- Relationship structure/status
- Intentions
- Discovery preferences
- Bio/interests
- Photos/storage integration when configured
- Privacy settings
- Create/update profiles/{uid}

Exit criteria: onboarding persists and returning users load the same profile.

## Phase 3 — Circle / Relationship Cards
- Card list
- Add/edit/delete/deactivate
- Reorder
- Privacy controls
- Public/matches/private/unnamed behavior

Exit criteria: card data persists and unauthorized users cannot edit it.

## Phase 4 — Discover
- Profile cards
- Profile detail
- Filter UI
- Exclude self/hidden/blocked/inactive users
- Pagination

Exit criteria: two seeded/test users see appropriate candidates based on filters and privacy.

## Phase 5 — Likes & Connections
- Like action
- Duplicate prevention
- Reverse-like lookup
- Canonical mutual match creation
- Connections list

Exit criteria: mutual likes create exactly one connection.

## Phase 6 — Messaging
- One-to-one conversation creation
- Conversation list
- Text messages
- Read state
- Pagination/order
- Empty/error/loading states

Exit criteria: connected users exchange messages; unrelated users cannot access conversation data.

## Phase 7 — Safety
- Block
- Report
- Block enforcement across Discover/profile/matches/messages
- Report confirmation
- Firestore rules review

Exit criteria: blocked users cannot continue interaction and reports persist safely.

## Phase 8 — QA & Beta Readiness
- End-to-end acceptance journey
- Accessibility pass
- Performance/query pass
- Firestore index pass
- Security-rule test pass
- Error/empty-state review
- Beta seed data

## Later Releases
- visual interactive polycule graph
- verified linked partners/mutual relationship confirmation
- groups/community spaces
- local events
- push notifications
- profile verification
- premium subscriptions
- advanced filters
- see-who-liked-you
- moderation tooling
- web version