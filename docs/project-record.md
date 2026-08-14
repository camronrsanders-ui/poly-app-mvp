# Polycircle — Project Record

This document is the durable project record for major engineering, security, release-readiness, product-direction, and testing decisions made while rebuilding Polycircle. It complements Git history and the detailed roadmap; it is not a substitute for source control.

## Record-keeping rules

- Keep entries concise, dated, and grouped by area.
- Record meaningful changes, fixes, test-cycle outcomes, blockers, and product decisions rather than every trivial edit.
- Git commits remain the authoritative record of exact code changes.
- `docs/development-roadmap.md` remains the implementation/product roadmap.
- `docs/post-launch-product-vision.md` remains the after-plan for longer-term product/business work.
- `docs/business/investor-readiness-plan.md` remains the working business/fundraising/acquisition-readiness plan.
- Security-sensitive values, credentials, signing secrets, tokens, private keys, or personal user data must never be copied into this record.
- Private Vault remains OFF until its documented release gates are explicitly satisfied.
- Do not record a feature as shipped merely because it appears in planning documentation.

## Current engineering priority

1. Keep the Flutter application runnable and reduce preventable test-cycle failures.
2. Maintain CI, dependency auditing, security contracts, and Firebase rules tests.
3. Complete Android Firebase runtime/emulator and real-device validation now that the native host and CI debug APK build are established.
4. Continue iOS real-device/runtime validation.
5. Preserve App Check, Firestore/Storage protections, and release gates.
6. Do not enable paid Firebase infrastructure merely to advance development.
7. Keep PR #4 on `restart-foundation` Draft/unmerged until release criteria justify changing that state.

## Engineering record

### 2026-08-14 — Android native host and CI APK milestone
- The native `android/` Flutter host is now committed on `restart-foundation` with the permanent Android application ID `com.polycircle.app`.
- CI now requires a real `flutter build apk --debug` on every run rather than conditionally skipping Android when the native host is absent.
- CI uses a temporary non-secret build-only Firebase configuration solely for compile validation; real local/device runtime testing still requires the genuine git-ignored `android/app/google-services.json` for `com.polycircle.app`.
- Android bootstrap/recovery tooling preserves the permanent package identity and local preflight verifies both Firebase project ID and Android package identity before runtime testing.
- Latest verified milestone baseline: Polycircle CI #969 and Dependency Audit #316 passed on `600758b7b2f05aee6679d5efbd5c184cf82cab2e`, including Android debug APK build, normalized iOS simulator build, Flutter analysis/tests, Functions checks, security contracts, and Firestore/Storage adversarial rules.
- Remaining Android blocker is runtime acceptance rather than basic compilation: genuine Firebase config, emulator journey, and physical-device testing are still required.

### 2026-08-12 — Android test preparation
- Added guarded Android local-run tooling and Android development/readiness documentation.
- Android emulator Firebase routing is designed around `10.0.2.2` while seed/admin tooling remains loopback-only.
- Added preflight/contract protections so incomplete Android Firebase/native configuration fails explicitly instead of presenting a false ready state.
- Added a conditional CI Android debug-APK gate so a committed Android native host will automatically begin receiving build validation.
- Historical blocker at this point: native `android/` Flutter host and matching Firebase Android configuration still needed to exist before APK/device validation could complete. The native-host/APK portion was completed on 2026-08-14; runtime/device validation remains outstanding.

### 2026-08-12 — CI/runtime hardening
- Updated GitHub Actions runtime dependencies to current Node-24-compatible action generations while preserving the application's required Node runtime.
- Added regression protection around the Discover reload path after a successful Like/Pass action so asynchronous work does not leak through a synchronous Flutter `setState` callback.
- Strengthened local development preflight to run full-project `flutter analyze`, matching the CI/release-gate scope rather than analyzing only `lib`.
- Continued dependency-audit and security-contract coverage alongside normal CI.

### 2026-08-12 — Security/release posture
- Private Vault remains OFF.
- Firestore/Storage rules and App Check must not be weakened to simplify local testing.
- No paid Firebase services are to be enabled as part of the current preparation work.
- Security and release gates remain authoritative even when a feature appears functionally complete.

## Product-direction record

### 2026-08-12 — Past Connections + Mutual Reconnection
- Future connection endings should distinguish **End for now**, **End permanently**, and **Block & end**.
- End-for-now may preserve a private past-connection record eligible for a later explicit reconnection request.
- Reconnection requires mutual consent and must never silently resurface a former connection in Discover.
- Permanent ending prevents normal future rematching/reconnection.
- Blocking remains the strongest safety boundary and overrides reconnection/archive behavior.
- Message-history retention/restoration remains a separate privacy/product decision.

### 2026-08-12 — Circle as signature relationship experience
- Future Circle should evolve beyond a flat relationship-card list into a fluid, interactive circular/constellation relationship map.
- Relationship networks can rotate/move naturally, focus on selected nodes, and condense multiple separate circles into expandable clusters.
- Dense networks require progressive disclosure and stable deterministic layout rather than visual clutter.
- Existing relationship privacy/redaction rules remain authoritative for every node and connection shown.
- Equivalent accessible navigation/list representation is required; gestures cannot be the only interaction method.
- Build in stages after the cross-platform foundation is stable: data/privacy model, static prototype, interaction/motion, multi-circle expansion, accessibility/performance, then device polish.

### 2026-08-12 — Community Learning & Support Hub
- Future public resource area should center on **Learn, Grow, Connect, and Get Help**.
- Planned areas include a plain-language relationship dictionary, relationship/communication education, growth/check-in tools, and carefully vetted safety/community resources.
- Safety resources require source, region, and review-date maintenance rather than unverified hard-coded information.
- Educational material should acknowledge varied relationship models and contested/evolving terminology instead of dictating one correct way to practice polyamory/ENM.
- Safety-critical resources should remain accessible without a premium subscription.
- Avoid sensitive telemetry around crisis/safety-resource use unless a future privacy review establishes a compelling need.

### 2026-08-12 — Post-launch product/business principles
Preserved in `docs/post-launch-product-vision.md`:

> **Polycircle shouldn't dictate how people must love. It should give people understandable language, safer tools, trustworthy resources, and thoughtful product mechanics that help them love, grow, and connect with greater communication, consent, and care.**

> **Discover helps you meet. Circle helps you understand how you're connected. Resources help you learn and grow. Reconnection acknowledges that relationships can change without pretending the history never happened.**

Long-term pillars:
- **Meet — Discover**
- **Understand — Circle**
- **Grow — Community Learning & Support**
- **Evolve — Past Connections & Reconnection**

These are future product/business-positioning principles. They do not override current engineering priorities.

## Business-development record

### 2026-08-13 — Investor and acquisition readiness begins
- Added `docs/business/investor-readiness-plan.md` as the working business-development plan.
- Established two operating perspectives for future work: **Product Engineer** for reliability/security/execution and **Founder / Entrepreneur** for market evidence, positioning, distribution, monetization, partnerships, fundraising, and enterprise value.
- The business plan is intended to support multiple options: independent growth, outside investment, strategic partnerships, or eventual acquisition interest.
- Investor-readiness work will include the executive summary, sourced market research, competitive landscape, customer discovery, go-to-market strategy, monetization, traction/KPIs, financial model, funding strategy, buyer landscape, corporate/IP readiness, data-room preparation, pitch materials, and diligence records.
- Category leaders such as Grindr can be studied for lessons in distribution, retention, monetization, network effects, brand strength, and strategic value, but Polycircle should not be positioned as a copy. Its investment story should be built around its distinct relationship-lifecycle product thesis.
- Business work remains secondary to current app stability, security, Android/iOS testing, and release readiness.

## Current document map

- `docs/development-roadmap.md` — implementation roadmap and future feature direction.
- `docs/post-launch-product-vision.md` — longer-term product/business after-plan.
- `docs/business/investor-readiness-plan.md` — working business plan, investor preparation, fundraising, and acquisition-readiness roadmap.
- `docs/project-record.md` — durable high-level record of decisions, major maintenance work, test outcomes, and blockers.
- Android/iOS/security/release documentation — operational details and platform-specific procedures remain in their dedicated documents rather than being duplicated here.

## Maintenance convention

For future substantial maintenance cycles, append or update this record when there is a durable change worth preserving: a significant regression/fix, platform-readiness milestone, release/security decision, major blocker, product-direction decision, or material business-readiness milestone. Routine successful CI reruns do not need individual permanent entries unless they validate a meaningful milestone.
