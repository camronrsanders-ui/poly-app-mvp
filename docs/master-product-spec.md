# Polycircle — Master Product Specification

## Product Vision
Polycircle is a mobile-first dating, friendship, relationship, and community app designed primarily for polyamorous, ethically non-monogamous (ENM), open-relationship, relationship-anarchy, LGBTQ+, and relationship-exploring users.

Polycircle must not feel like a generic dating app with a poly tag. Relationship structure, intention, transparency, consent, and community are first-class product concepts.

## Brand
Name: Polycircle
Tagline: Connect openly. Love honestly. Build your circle.
Tone: warm, modern, inclusive, mature, safe, community-centered, transparent.
Avoid: hookup-only framing, binary identity assumptions, clinical language, or a direct Tinder clone.

## Core Differentiators
1. Poly/ENM-first relationship structure.
2. Multi-intention profiles: friendship, community, dating, long-term, casual, join a polycule, build/grow a polycule, exploring/learning.
3. Inclusive gender identity, pronouns, and orientation.
4. Relationship cards as the MVP foundation for future visual polycule mapping.
5. Community and friendship are equal product modes, not secondary features.

## MVP User Journey
1. User opens app.
2. User signs up with email/password.
3. User completes onboarding.
4. User creates profile and privacy settings.
5. User may add relationship cards or skip.
6. User enters Discover.
7. User filters and views compatible profiles.
8. User likes/connects with another user.
9. Mutual interest creates one connection/match.
10. Matched users can message.
11. Users can edit profiles/cards, block, report, logout, and return later with data intact.

## Main Navigation
- Discover
- Connections
- Circle
- Messages
- Profile

Circle is the home for relationship cards and future visual polycule mapping.

## Authentication
MVP requirements:
- Email/password signup
- Login
- Logout
- Forgot/reset password
- Persistent authentication
- Auth-protected routes
- New users routed to onboarding
- Completed users routed to main app

## Profile & Identity
Profiles support:
- display name
- age
- city / region
- bio
- headline
- photos/avatar
- gender identity
- pronouns
- orientation
- custom identity tags
- relationship structure
- relationship status
- partnered flag
- open-to-connections flag
- intentions
- interests
- what-they-are-looking-for note
- discovery age/distance preferences
- preferred relationship structures and intentions
- profile and map visibility

Identity controls must be flexible and allow self-described/custom values.

## Relationship Structures
Examples:
- solo poly
- hierarchical poly
- non-hierarchical poly
- open relationship
- polyfidelity
- relationship anarchy
- monogamish
- exploring
- custom/self-described

Provide short optional definitions so newer users are not excluded by unfamiliar terminology.

## Intentions
Allow multiple simultaneous selections:
- friendship
- community
- dating
- long-term relationship
- casual connection
- join a polycule
- build/grow a polycule
- exploring/learning

Do not assume every connection is romantic or sexual.

## Relationship Cards — Signature MVP Feature
Each user may create multiple relationship cards representing important connections.

Supported actions:
- create
- view
- edit
- reorder
- deactivate
- delete

Possible connection types:
- nesting partner
- anchor partner
- primary partner
- secondary partner
- romantic partner
- sexual partner
- queerplatonic partner
- comet partner
- platonic life partner
- important connection
- custom

Hierarchy labels are optional, never required.

## Relationship Privacy
Relationship cards support:
- public
- matches_only
- private
- unnamed_public

An unnamed public card may expose relationship type/status without exposing a person's identity.

Never expose another person's identity merely because a user entered their name. Future architecture may support verified linked accounts and mutual approval.

## Future Polycule Map
Phase 2 should render a visual relationship network using relationship-card/relationship data as nodes and edges. The MVP must be structured so this future graph can be added without replacing the entire data model.

Potential future connection edge types:
- romantic
- nesting
- queerplatonic
- sexual
- platonic
- custom

## Discover
Profile cards should display, when allowed:
- photo
- display name
- age
- location
- pronouns
- relationship structure
- relationship status
- intention badges
- headline/bio excerpt
- relationship-map/card preview

Actions:
- pass
- like/connect
- view profile

Swiping may exist, but discovery must not depend entirely on swipe gestures.

## Discover Filters
Support:
- age range
- distance
- relationship structure
- intentions
- gender preference/identity where configured
- open-to-connections

Exclude:
- current user
- blocked users
- hidden profiles
- suspended/banned accounts

MVP matching should be transparent and rule-based, not AI compatibility scoring.

## Likes & Matches
A like stores fromUid, toUid, createdAt.
A mutual like creates exactly one match/connection.
Prevent duplicate likes, self-likes, and duplicate matches.
Use a canonical user-pair strategy for matches.

## Connection Language
Prefer inclusive wording such as connection / you connected / new connection when romance is not guaranteed.

## Messaging
Matched users may create one-to-one conversations and send text messages.
MVP requires:
- chronological message list
- send text
- unread/read tracking
- conversation lastMessageAt
- empty/error/loading states
- block/report access

Future: photos, voice notes, reactions.

## Blocking
Blocking must actually affect app behavior:
- blocked users disappear from Discover
- blocked profiles are not interactable
- messaging is prevented
- existing conversations cannot bypass the block
- new matches cannot be created

## Reporting
Report reasons should include:
- harassment
- fake_profile
- hate_speech
- misrepresentation
- spam
- nonconsensual_content
- other

Default report status: open.

## Community Guidelines
Polycircle should reinforce:
- honest relationship status
- informed consent
- respect for boundaries
- respect for names/pronouns/identity
- no harassment or coercion
- no threats
- no deceptive partner-status claims
- no outing users
- no discrimination
- no impersonation
- no nonconsensual sharing of private information/content

The product may discourage deceptive/coercive unicorn-hunting behavior without condemning consensual multi-person relationship structures.

## Privacy
profileVisibility:
- public
- hidden
- matches_only (if appropriate)

mapVisibility:
- public
- matches_only
- private

Individual relationship-card settings should be able to be more restrictive than overall map settings.

## Security
Do not ship unrestricted Firestore rules.
Ownership and membership must be enforced in backend security rules, not only hidden in UI.
No client code should contain admin/service-account secrets.

## UX Requirements
Every major operation needs:
- loading state
- success state
- empty state
- error state

Accessibility:
- readable sizing
- strong contrast
- accessible tap targets
- semantic labels
- screen-reader-friendly controls
- do not communicate status by color alone

## Performance
Use pagination/query limits and lazy loading. Avoid downloading every profile or entire message histories at once.

## Definition of Done
The MVP is only complete when a real user can sign up, onboard, create/edit a profile, create relationship cards, discover/filter users, like/match, message, block/report, log out, log back in, and retain their data with correct privacy and security behavior.