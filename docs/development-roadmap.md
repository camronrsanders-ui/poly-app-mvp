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

### Community Learning & Support Hub
Polycircle should help people understand relationships and care for themselves and their communities, not only help them find connections. Add a clearly accessible public resource area built around **Learn, Grow, Connect, and Get Help**. Core educational/safety material should be useful without requiring a match or active relationship and, where technically practical, critical safety information should remain accessible without relying on personalized account data.

Product direction:
- **Relationship dictionary:** plain-language, respectful definitions for polyamory, ethical/consensual non-monogamy, monogamish, relationship anarchy, metamour, compersion, nesting partner, anchor partner, kitchen-table polyamory, parallel polyamory, hierarchy/prescriptive hierarchy, boundaries, agreements, consent, safer-sex terminology, and other evolving community language.
- Definitions should educate rather than prescribe a single correct relationship model. Where terminology is contested or community usage varies, say so rather than presenting opinion as universal fact.
- **Relationship learning:** practical guides for communication, boundaries versus rules, jealousy and insecurity, consent, conflict repair, expectations, introducing partners/metamours, check-ins, ending relationships respectfully, reconnecting, and building healthy relationship agreements.
- **Growth tools:** optional conversation prompts, relationship check-in questions, boundary/needs reflection prompts, and educational exercises. These should support conversation rather than claim to replace counseling or professional care.
- **Safety & Get Help:** prominent routes to emergency/safety information, domestic or intimate-partner violence resources, sexual-assault resources, crisis support, LGBTQ+ support, and other vetted community services where appropriate.
- Safety resources must distinguish immediate emergency help from general educational material and must not depend on another Polycircle user granting access.
- Resource links/phone information must have source, region, and review-date metadata so stale safety information can be identified and maintained. Do not hard-code unverified crisis information merely to fill the section.
- Allow future localization by country/region because emergency numbers, laws, organizations, terminology, and available services differ.
- **Community resources:** eventually include vetted books, organizations, support groups, educational sites, sexual-health resources, and community services. Inclusion must not imply an endorsement that has not actually been reviewed.
- Keep educational content separated from user-generated advice so authoritative/vetted material is visually identifiable.
- Make the hub searchable and organized enough that a person unfamiliar with poly/ENM language can find an answer without already knowing the correct term.
- Design for accessibility, readable language, and discreet access to safety information.
- Avoid collecting sensitive telemetry about which crisis/safety resources an individual opens unless there is a clearly justified, privacy-reviewed need.

Editorial/maintenance requirements:
- Establish source and review standards before publishing safety-critical content.
- Track `lastReviewed`/region/source metadata for externally maintained resources.
- Have terminology and educational content reviewed periodically because language and community norms evolve.
- Clearly distinguish education from medical, legal, mental-health, or emergency professional advice.
- Build the initial content as maintainable structured data rather than scattering definitions and resource URLs throughout UI code.

Long-term product principle: Polycircle should not position itself as an authority that dictates how people must love. It should give people understandable language, safer tools, trustworthy resources, and thoughtful product mechanics that help them **love, grow, and connect** with greater communication, consent, and care.

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
