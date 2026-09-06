# Polycircle Coding Agent Instructions

Read README.md and every file under docs/ before making architectural decisions.

## Mission
Build a production-minded Flutter MVP of Polycircle from the repository specifications. The product source of truth is docs/build-spec.md plus the schema, screen map, onboarding, architecture, roadmap, and security documents.

## Working rules
1. Inspect before changing.
2. Preserve working code when it satisfies the specification.
3. Do not switch frameworks without a blocking technical reason.
4. Use Flutter with Firebase Auth and Cloud Firestore as defined in the architecture.
5. Never commit or expose secrets, service-account credentials, passwords, signing keys, tokens, or private user data.
6. Do not use fake buttons, disconnected screens, or hard-coded demo behavior as finished functionality.
7. Build in small phases and keep the app buildable.
8. Run the strongest applicable local checks after meaningful changes when the environment permits.
9. Fix P0 build/security errors before adding features.
10. Document manual Firebase console steps that cannot be performed from the development environment.

Preserve accessibility, privacy, consent boundaries, and a runnable app throughout development. Do not make product-policy decisions silently. Safe code, test, and documentation hardening may be done autonomously. Ask before enabling paid infrastructure, changing unresolved policy decisions, performing destructive operations, deploying production or staging infrastructure, or weakening protections.

## Branch and Git safety
- The primary development branch is `restart-foundation`.
- Never modify `main`.
- Never merge PR #4 unless the founder explicitly changes this rule. PR #4 must remain draft unless explicitly instructed otherwise.
- Inspect `git status` before meaningful work.
- Never force-push.
- Never use `git reset --hard` on founder work.
- Never discard uncommitted or unknown local work.
- Do not merge or cherry-pick `safety/local-circle-work-2026-08-18` without explicit instruction.
- Prefer small, reviewable commits.

## Android / iOS parity
- Polycircle is one Flutter product; do not treat Android and iOS as separate feature implementations.
- `restart-foundation` is the source of truth for both platforms.
- Shared behavior belongs in Flutter unless a native OS API genuinely requires platform-specific host code.
- Whenever Android- or iOS-specific behavior changes, inspect the corresponding implementation on the other platform before calling the work complete.
- Keep Flutter-facing native channel names, payload shapes, security boundaries, app identity, Firebase expectations, permissions, and user-visible behavior compatible across both platforms unless a deliberate documented OS difference requires otherwise.
- After native-facing or shared product changes, require both the Android debug APK build and iOS simulator build to pass in CI.
- Keep `tests/contracts/native_platform_parity_contract.test.mjs` passing and extend it when new cross-platform native behavior is added; never weaken it just to land a one-platform change.
- Real-device validation on both Android and iOS remains a separate external-beta release gate.
- See `docs/platform-parity.md` for the maintained parity checklist and consolidation history.

## Private Vault
- Flutter `privateVaultEnabled` must remain `false`.
- Backend `privateVaultServerEnabled` must remain `false`.
- Never enable either flag merely because implementation exists.
- Private Vault may be enabled only after its dedicated release gates are explicitly approved.
- Never weaken Private Vault authorization, consent, moderation, deletion, retention, or security controls.

## Firebase and security
- Never weaken Firestore Rules, Storage Rules, or App Check.
- Never bypass security tests to make CI pass.
- Never expose Firebase secrets, service credentials, signing keys, tokens, or private user data.
- Never enable paid Firebase or cloud services without explicit founder approval.
- Prefer local Firebase emulators for development and testing when available.
- Do not deploy to production.
- Do not deploy staging infrastructure unless explicitly instructed.

## Testing expectations
After meaningful code changes, run the strongest applicable local checks available:

- Dart formatting or a formatting check;
- `flutter analyze`;
- `flutter test`;
- an Android debug build;
- an iOS simulator build when the environment permits;
- a locked Functions dependency install;
- the Functions TypeScript build;
- Functions tests;
- a compiled Functions module-load smoke test;
- client/backend security contract tests; and
- Firestore/Storage emulator adversarial Rules tests when applicable.

If a check fails, investigate the actual cause. Do not suppress legitimate failures. Fix safe regressions, rerun the affected checks, and report anything that remains blocked.

## Build order
P0: project scaffolding/build health; Firebase configuration; security baseline.
P1: authentication; onboarding; profiles; Circle relationship cards; Discover; likes/matches; conversations/messages; block/report; privacy enforcement.
P2: UI polish; accessibility; performance; test coverage; analytics hooks.
P3: future graph, verified relationships, groups/events, subscriptions, AI enhancements.

Prefer P0/P1 correctness and security work over polish.

## Product direction

### Discover
Discover is one combined experience:

`Orbit Discovery -> Profile World -> Why Our Worlds Cross -> Connect / Message`

#### Orbit Discovery
- This is the primary Discover interaction.
- Members can swipe or rotate through profiles.
- Accessible alternative controls must remain available.
- Pass and Connect remain explicit user actions.

#### Profile World
- Present an immersive profile experience.
- Preserve protected-media access controls.
- Preserve Circle privacy.
- Preserve block and report behavior.

#### Why Our Worlds Cross
- Show factual shared information only.
- Shared interests, intentions, or matching relationship structure are acceptable.
- Do not use fake compatibility percentages, inferred psychology, or AI compatibility scoring unless explicitly designed and approved.
- If no factual overlap exists, do not invent one.

### Messages
Messages is one combined experience:

`Conversation Space -> intentionally saved Shared Moments -> structured Plans`

#### Conversation Space
- Use a compact identity/header treatment.
- The majority of the viewport belongs to the actual conversation.
- Preserve sending, read receipts, reporting, blocking, and UGC protections.

#### Shared Moments
- Saving is explicit and manual for the first release.
- Do not add automatic AI memory detection.
- Do not ship decorative fake buttons.
- Persistence, authorization, deletion, retention, and reporting behavior must exist before enabling the UI.

#### Plans
- Use a small structured plan model for the first release.
- Plans require participant authorization, editing and cancellation rules, account-cleanup/deletion behavior, and retention behavior.
- Do not add calendar or location automation until separately approved.

## Product story
- Discover: Explore their world.
- Profile: Understand where your worlds intersect.
- Messages: Create a world together.
- My Circle: See how your worlds connect.

## Business documentation
- Approved product mockups belong in the Polycircle business-plan visual record.
- Investor and demo materials must distinguish approved vision from functionality actually implemented.
- Never describe roadmap functionality as shipped traction.

## Acceptance behavior
Before calling the MVP complete, verify two fictional users can sign up, onboard, create profiles, add relationship cards, discover each other, mutually like, create exactly one match, create exactly one conversation, exchange messages, then block and prevent further communication/access as specified. Verify logout/login persistence and Firestore authorization.

## When taking over this repo
First report: current stack; current files/screens; Firebase state; what builds; what is broken; security risks; missing MVP requirements; proposed changes. Then implement rather than only returning snippets when file modification is available.
