# Polycircle — AI Build Instructions

These instructions are intended for Gemini Code Assist, Codex, or another coding agent working directly inside this repository.

## Source of Truth
Read these files first:
1. `docs/master-product-spec.md`
2. `docs/firestore-schema.md`
3. `docs/screen-map.md`
4. `docs/onboarding-flow.md`

Product behavior in those files is authoritative unless the owner explicitly changes it.

## Takeover Procedure
Before editing code:
1. Inspect the repository.
2. Identify the actual framework/language and versions.
3. Inspect `pubspec.yaml`, routing, Firebase config, dependencies, assets, models, services, security rules, and existing screens.
4. Run the available diagnostic/build commands.
5. Report what works, what is broken, what is missing, and what you plan to modify.
6. Preserve working code whenever practical.

Do not switch frameworks merely because you prefer another stack.

## If This Repository Has No App Yet
Create a clean Flutter mobile application that supports iOS and Android and is structured for Firebase Authentication and Firestore. Use maintainable feature-oriented code rather than a single giant file.

## Build Priority
P0:
- project compiles/runs
- Firebase configuration is correct
- Firestore security is not open/unrestricted

P1 MVP:
1. Authentication
2. Onboarding
3. Profiles
4. Relationship cards
5. Discover
6. Likes and canonical mutual matches
7. Conversations
8. Messaging
9. Blocking
10. Reporting
11. Privacy enforcement
12. End-to-end QA

P2:
- polish
- accessibility improvements
- analytics hooks
- push notifications

P3 Future:
- interactive visual polycule graph
- linked/verified partner accounts
- groups/events
- subscriptions
- advanced matching

## Implementation Rules
- Do not create disconnected placeholder buttons.
- Do not use fake backend responses in production paths.
- Do not expose secrets in client code.
- Use server timestamps where appropriate.
- Validate ownership/membership with Firestore rules.
- Prevent duplicate likes, matches, and one-to-one conversations.
- Respect blocks in Discover, matching, profile access, and messaging.
- Build loading, error, success, and empty states.
- Use pagination/query limits for lists.
- Prefer understandable rule-based matching for MVP.
- Do not build AI compatibility scoring until core matching works.
- Do not build the complex graph before relationship cards work.

## Verification Cycle
After each major feature:
1. run formatter/analyzer
2. run tests
3. run/build the app if environment permits
4. inspect console/runtime errors
5. fix errors before advancing

Do not claim a feature is complete merely because code exists.

## Acceptance Journey
Before declaring MVP complete, verify:

User A:
signup -> onboarding -> profile -> relationship card -> discover

User B:
signup -> onboarding -> profile -> discover -> likes User A

User A:
likes User B -> exactly one mutual match -> opens conversation -> sends message

User B:
reads/replies

User A:
blocks User B

Verify after block:
- further messaging is prevented
- Discover respects block
- profile access respects block
- no new match bypass exists

Also verify:
- logout/login preserves data
- profile edits persist
- relationship card edits persist
- privacy settings work
- reports save correctly
- normal flows do not hit unexpected permission failures
- production rules are not unrestricted

## First Agent Response
Before large code changes, report:
A. What I found
B. What already works
C. What is broken
D. What is missing
E. Security concerns
F. Proposed build plan
G. Files/components expected to change

Then proceed with implementation when the environment permits file edits.