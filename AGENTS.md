# Polycircle Coding Agent Instructions

Read README.md and every file under docs/ before making architectural decisions.

## Mission
Build a production-minded Flutter MVP of Polycircle from the repository specifications. The product source of truth is docs/build-spec.md plus the schema, screen map, onboarding, architecture, roadmap, and security documents.

## Working rules
1. Inspect before changing.
2. Preserve working code when it satisfies the specification.
3. Do not switch frameworks without a blocking technical reason.
4. Use Flutter with Firebase Auth and Cloud Firestore as defined in the architecture.
5. Never commit secrets, service-account credentials, passwords, or private signing keys.
6. Do not use fake buttons, disconnected screens, or hard-coded demo behavior as finished functionality.
7. Build in small phases and keep the app buildable.
8. Run formatter, analyzer, and tests after meaningful changes when the environment permits.
9. Fix P0 build/security errors before adding features.
10. Document manual Firebase console steps that cannot be performed from the development environment.

## Build order
P0: project scaffolding/build health; Firebase configuration; security baseline.
P1: authentication; onboarding; profiles; Circle relationship cards; Discover; likes/matches; conversations/messages; block/report; privacy enforcement.
P2: UI polish; accessibility; performance; test coverage; analytics hooks.
P3: future graph, verified relationships, groups/events, subscriptions, AI enhancements.

## Acceptance behavior
Before calling the MVP complete, verify two fictional users can sign up, onboard, create profiles, add relationship cards, discover each other, mutually like, create exactly one match, create exactly one conversation, exchange messages, then block and prevent further communication/access as specified. Verify logout/login persistence and Firestore authorization.

## When taking over this repo
First report: current stack; current files/screens; Firebase state; what builds; what is broken; security risks; missing MVP requirements; proposed changes. Then implement rather than only returning snippets when file modification is available.
