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

## Future Relationship-System Work

### Past Connections + Mutual Reconnection
- Replace a single ambiguous end-connection action with explicit relationship outcomes.
- **End for now:** close the active connection while retaining a private Past Connections/archive entry for eligible future reconnection.
- A past connection must not silently return to Discover or automatically become active again.
- Either eligible former connection may later send an explicit reconnection request.
- The recipient sees a clear state such as **Seeking reconnection** and can accept, decline, or permanently end the connection.
- Reconnection requires mutual consent before restoring active connection privileges.
- **End permanently:** close the connection and prevent the pair from matching/reconnecting again through normal product flows.
- **Block & end:** remains the strongest safety boundary and overrides archive/reconnection behavior. Blocking must prevent profile access, archive visibility to the blocked party, reconnection requests, and future matching.
- Conversation-history restoration/retention must remain a separate product/privacy decision; do not silently restore messages until retention behavior is finalized.

### Circle — Signature Interactive Relationship Map
The Circle experience is intended to become a defining Polycircle feature, not merely a list of relationship cards. Connection-building is the product foundation, so this experience should receive a dedicated interaction/design phase after the current cross-platform foundation is stable.

Product direction:
- Present the member's relationship network as an elegant, interactive circular/constellation-style graph.
- The member is an obvious visual anchor while partners/connections occupy relationship nodes around the structure.
- Nodes and relationship paths communicate how people connect without implying hierarchy unless the users explicitly define one.
- The graph can be dragged/rotated/spun naturally, with smooth inertial movement and deliberate snapping/focus behavior rather than a static diagram.
- Tapping a person or relationship expands contextual details while keeping the surrounding network understandable.
- Multiple separate relationship circles/networks are initially condensed into clean clusters to prevent visual overload.
- Selecting a condensed cluster smoothly expands that specific network; leaving it returns to the compact overview.
- Dense networks should progressively disclose detail rather than rendering unreadable labels and crossing lines all at once.
- Visual treatment should feel modern, fluid, intimate, and technically distinctive rather than like a business flowchart.
- Relationship-card privacy rules remain authoritative. The visualization must never infer, expose, or draw a private relationship that the viewer is not authorized to see.
- Unnamed/redacted relationship-card behavior must remain redacted in the graph.
- Verified/linked partner relationships can eventually use a distinct visual state, but the UI must not imply verification where none exists.
- Accessibility requires a non-gesture-only way to navigate the same relationship information, including screen-reader semantics and an equivalent structured/list representation.
- Performance work should include deterministic graph layout, bounded animation cost, graceful behavior for large polycules, and stable positioning so the graph does not randomly reorganize on every load.

Implementation should be staged: first establish the graph data/view model and privacy-safe layout tests; then a static interactive prototype; then motion/gesture behavior; then dense/multi-circle expansion; then accessibility/performance and real-device polish. Do not rush this into the current foundation merely for visual novelty.

## Later Releases
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
