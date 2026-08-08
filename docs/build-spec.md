# Polycircle MVP Build Specification

## Product promise
Polycircle is a mobile-first polyamory / ethical non-monogamy dating and community app. It supports dating, friendship, community, relationship exploration, and multiple simultaneous relationship structures. It must not behave like a monogamy-first dating app with a poly tag added.

## Brand
Name: Polycircle
Tagline: Connect openly. Love honestly. Build your circle.
Tone: warm, mature, inclusive, transparent, safe, community-centered, not hookup-only.

## Main navigation
Discover | Connections | Circle | Messages | Profile

## MVP functional journey
1. User signs up with email/password.
2. A users/{uid} record is created with onboardingComplete=false.
3. User completes multi-step onboarding.
4. A profiles/{uid} record is saved and onboardingComplete becomes true.
5. User can create/edit/delete/reorder relationship cards in Circle.
6. User browses visible compatible profiles in Discover.
7. User can like/connect with another user.
8. Mutual like creates exactly one match.
9. Matched users can start exactly one 1:1 conversation.
10. Users can exchange text messages.
11. Users can block/report others.
12. Block enforcement affects discovery, profile access, matching, and messaging.
13. Logout/login preserves persisted data.

## Authentication
Firebase Authentication: email/password, password reset, persistent auth state, protected routes. Route incomplete users to onboarding; completed users to Discover.

## Inclusive profile requirements
Support flexible gender identity, pronouns, orientation, custom identity tags, relationship structure, relationship status, intentions, interests, discovery preferences, profile visibility, and relationship-map visibility. Avoid binary-only controls. Allow custom/self-described identity values where reasonable.

## Relationship structures
Suggested values: solo poly, hierarchical poly, non-hierarchical poly, open relationship, polyfidelity, relationship anarchy, monogamish, exploring, custom/self-described. These are descriptors, not judgments.

## Intentions
Multi-select: friendship, community, dating, long-term relationship, casual connection, join a polycule, build/grow a polycule, exploring/learning.

## Circle / Relationship Cards
This is the signature MVP feature and future foundation for a visual polycule graph. Users can create multiple cards with connection type, optional display name, status, note, visibility, ordering, and active state.

Connection types may include nesting_partner, anchor_partner, primary_partner, secondary_partner, romantic_partner, sexual_partner, queerplatonic_partner, comet_partner, platonic_life_partner, important_connection, custom. Never force hierarchy labels.

Privacy: public, matches_only, private, unnamed_public. Do not expose another person's identity merely because the owner typed their name. Future architecture should support linked/verified accounts and mutual relationship confirmation.

## Discover
Card/list discovery with View Profile, Like/Connect, Pass. Filter by age, distance, relationship structure, intentions, and identity/preferences where configured. Exclude self, blocked users, hidden profiles, and suspended/banned accounts. Respect openToConnections and privacy. MVP matching is rule-based, not AI compatibility scoring.

## Likes and matches
Prevent self-likes and duplicate likes. A reverse like creates a match. Use deterministic/canonical pair identity so A+B and B+A cannot create duplicate matches. Use trusted backend logic if client-only implementation cannot safely guarantee uniqueness.

## Messaging
Matched users can have a 1:1 conversation. Prevent duplicate conversations. MVP supports text messages, chronological loading, read state, lastMessageAt, loading/empty/error states, and access to block/report. Paginate message history.

## Safety
Blocking must have actual consequences across discovery, profiles, matching, and messaging. Reports include reason/details/status. Suggested reasons: harassment, fake_profile, hate_speech, misrepresentation, spam, nonconsensual_content, other.

## Community principles
Honesty about relationship status; informed consent; respect for boundaries, identity, names, and pronouns; no harassment/coercion/threats; no outing users; no discriminatory behavior; no impersonation; no nonconsensual sharing of private information/content.

## Privacy
profileVisibility: public, hidden, matches_only where technically appropriate.
mapVisibility: public, matches_only, private.
Individual relationship-card visibility may be more restrictive and should win.

## Backend
Firebase Auth + Cloud Firestore. Firebase Storage for profile photos when implemented. Firebase Cloud Messaging later. Cloud Functions/trusted server logic where security/uniqueness requires it. No admin/service-account secrets in the client.

## Performance
Use query limits, pagination/lazy loading, appropriately scoped realtime listeners, compressed/resized profile images, and required Firestore indexes. Do not fetch all profiles or complete message histories.

## Accessibility
Readable text, sufficient contrast, semantic labels, accessible tap targets, screen-reader-friendly controls, and no meaning conveyed by color alone.

## Definition of done
A feature is not complete because a screen exists. It requires working navigation, backend persistence, authorization/security, validation, loading state, empty state, error state, and tests appropriate to the implementation.

## Future after MVP
Interactive visual polycule graph, linked/verified partner accounts, mutual relationship confirmation, groups, local events, education/resources, verification, push notifications, premium subscription, boosts, advanced filters, see-who-liked-you, moderation assistance, optional compatibility recommendations, web app.
