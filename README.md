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

## Planned Stack
- Flutter mobile app (iOS + Android)
- Firebase Authentication
- Cloud Firestore
- Firebase Storage for media when configured
- Firebase Cloud Messaging later
- GitHub as the source of truth

## Documentation
Read these before implementing the app:

1. [`docs/master-product-spec.md`](docs/master-product-spec.md) — complete product requirements
2. [`docs/firestore-schema.md`](docs/firestore-schema.md) — database model
3. [`docs/screen-map.md`](docs/screen-map.md) — pages and navigation
4. [`docs/onboarding-flow.md`](docs/onboarding-flow.md) — onboarding behavior
5. [`docs/technical-architecture.md`](docs/technical-architecture.md) — technical direction
6. [`docs/development-roadmap.md`](docs/development-roadmap.md) — implementation phases
7. [`docs/ai-build-instructions.md`](docs/ai-build-instructions.md) — instructions for Gemini/Codex coding agents

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

## Current Status
This branch is the clean restart foundation. Product requirements and architecture are being established before application generation so an AI coding agent can build against one consistent source of truth.
