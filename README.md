# Polycircle

**Connect openly. Love honestly. Build your circle.**

Polycircle is a mobile-first dating, friendship, relationship, and community app designed for polyamorous, ethically non-monogamous (ENM), open-relationship, relationship-anarchy, LGBTQ+, and relationship-exploring users.

## Product Principles
- Poly/ENM-first, not a generic dating app with a tag.
- Friendship and community are equal to dating.
- Inclusive gender, pronoun, orientation, and self-description options.
- Relationship structure and intentions are first-class profile data.
- Relationship cards form the MVP foundation for future visual polycule mapping.
- Privacy, consent, transparency, and safety are core product behavior.

## Stack
- Flutter mobile app (iOS + Android)
- Firebase Authentication
- Cloud Firestore
- Firebase Cloud Functions for trusted state transitions
- Firebase Storage for protected media workflows
- Firebase App Check
- GitHub as the source of truth

## Documentation
Read these before implementing or releasing the app:

1. [`docs/master-product-spec.md`](docs/master-product-spec.md) — complete product requirements
2. [`docs/firestore-schema.md`](docs/firestore-schema.md) — database model
3. [`docs/screen-map.md`](docs/screen-map.md) — pages and navigation
4. [`docs/onboarding-flow.md`](docs/onboarding-flow.md) — onboarding behavior
5. [`docs/technical-architecture.md`](docs/technical-architecture.md) — technical direction
6. [`docs/development-roadmap.md`](docs/development-roadmap.md) — implementation phases
7. [`docs/local-development.md`](docs/local-development.md) — local Firebase Emulator Suite workflow, including development without a deployed Functions backend
8. [`docs/release-gates.md`](docs/release-gates.md) — required gates before external beta
9. [`docs/ai-build-instructions.md`](docs/ai-build-instructions.md) — instructions for AI coding agents

## MVP
A complete MVP allows a user to:

- sign up/login/reset password
- complete inclusive onboarding
- create and edit a profile
- choose relationship structure and intentions
- create/manage relationship cards with privacy controls
- discover and filter other users
- like/connect and form mutual matches
- exchange messages
- block and report users
- log out and return with data intact

## Signature Feature
The `Circle` area begins with relationship cards and is intentionally designed to evolve into an interactive polycule relationship map in a later release.

## Development Status
The rebuilt Flutter/Firebase foundation from `restart-foundation` merged into protected `main` through PR #4 on 2026-10-08. This **foundation merge was not a public-release approval**. Future work belongs on isolated review branches and must pass current-head automated checks and independently recorded manual signoffs before merge.

Automated CI covers Flutter analysis and tests, iOS/Android builds and emulator journeys, Functions TypeScript builds, contract checks, and Firebase security-rule tests. Draft PR #21 tracks the pre-billing visible-control/visual acceptance matrix; its manual iOS/Android checks remain separate from CI. Security and other design changes require independent review.

External staging App Check validation, real-device acceptance, operational moderation, final legal/policy signoffs, and release gates remain outstanding. Billing, paid infrastructure, Firebase deployment, and public release are **not** authorized by the merge or by green CI.

Cloud Functions deployment is not required to keep coding locally. Use the Firebase Emulator Suite workflow in [`docs/local-development.md`](docs/local-development.md) to exercise trusted backend behavior without weakening security boundaries or changing release configuration.
