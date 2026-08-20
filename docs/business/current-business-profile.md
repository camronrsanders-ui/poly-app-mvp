# Polycircle — Current Business Profile

_Last updated: 2026-08-20_

> **Status discipline:** This profile separates verified product progress from unfinished roadmap work. Investor, partner, buyer, press, or demo materials must not present emulator-verified or in-development features as publicly launched functionality.

## Company / product position

Polycircle is being developed as a relationship platform for modern connection structures, with particular strength in polyamorous, ENM, LGBTQ+, and other relationship contexts that are poorly represented by match-first dating products.

The product thesis remains broader than dating alone:

- **Meet — Discover**
- **Understand — Circle**
- **Grow — Community Learning & Support**
- **Evolve — Past Connections & Reconnection**

The core differentiation is not simply finding another profile. Polycircle is designed to help people understand how connections relate to one another, build consent-backed relationship structures, maintain clearer context, and access safety/community resources as relationships evolve.

## Verified product progress

### Core technical foundation

The application now has a substantial working foundation across Android and iOS development environments, including authentication, profile infrastructure, protected profile-photo handling, Discovery, Connections, Circle, messaging foundations, safety/privacy controls, Firebase-backed services, and an expanding automated contract/security test suite.

Android and iOS application identity / Firebase configuration have been migrated and validated under the Polycircle application identity. Release-readiness work remains separate from local/emulator validation.

### Circle: consent-backed relationship graph

A major product milestone has been proven end-to-end in the local Firebase/emulator environment:

1. a user creates a private Circle;
2. the Circle owner invites another person;
3. the invited person explicitly accepts or declines;
4. only accepted membership becomes active;
5. active membership is returned by the trusted Circle membership API;
6. the accepted person then appears inside the shared spatial Circle experience.

This establishes an important product/safety principle:

**Connection does not automatically equal Circle membership.**

Ordinary Connections are not silently inserted into a user's private relationship structure. Circle membership is consent-backed and separately represented.

### Shared spatial Circle proof

The Test House fixture has been visually verified with:

- Cam represented as the owner / central user;
- Jordan represented as an accepted member;
- member count correctly reaching two after acceptance;
- Jordan appearing as a real orbital member rather than being inferred from an ordinary Connection;
- the previous incorrect empty state ("Just you for now") removed once accepted-member data reaches Flutter;
- the owner able to open a dedicated **Manage Test House** view;
- the management view displaying **Members (2)**, **Cam — Owner • You**, **Jordan — Member**, and a persistent **Invite people** action.

This is meaningful product evidence because Circle's visual relationship model is now being driven by trusted membership state rather than UI-only placeholder logic.

### Account / test-flow reliability

Local testing has also verified working account switching/log-out behavior for the seeded Cam and Jordan accounts, making it possible to test both sides of consent-sensitive flows instead of evaluating only the owner's view.

## Current unfinished Circle work

The current Circle foundation is working, but the owner-management lifecycle is not yet complete. The next engineering milestone is:

- owner cancellation of a pending Circle invitation;
- owner removal of an active Circle member;
- management-screen display of pending invitations;
- immediate UI/orbit/member-count refresh after cancellation or removal;
- final wording/polish of context-aware Circle management actions;
- Android and iOS parity verification after the lifecycle is complete.

These items remain **roadmap/in-development**, not shipped functionality.

## Current readiness view

Internal planning estimate as of this update:

- **Core technical foundation:** approximately 90% of the present pre-launch foundation target.
- **Current Circle milestone:** approximately 80–85% complete.
- **Overall launch-readiness:** approximately 70–75% complete.

These percentages are internal planning estimates, not investor traction metrics and not substitutes for release certification, beta retention, customer discovery, or production usage data.

## Business significance of the latest milestone

The Circle architecture strengthens Polycircle's investor and partnership story in several ways:

- **Consent as product architecture:** relationship structure is not inferred merely because two users are connected.
- **Defensible interaction model:** Circle is becoming a functional relationship graph / spatial relationship experience rather than a decorative profile feature.
- **Safety and privacy differentiation:** membership state is explicit and separable from ordinary social/dating connections.
- **Lifecycle expansion:** Polycircle can extend beyond discovery and messaging into understanding and managing relationship context.
- **Demonstrable technical depth:** the product now has a working backend-to-client membership chain instead of a prototype-only visualization.
- **Diligence value:** automated tests, source-control discipline, Firebase separation, and explicit release-vs-emulator distinctions improve future investor/buyer readiness.

## Evidence classification

### Decisions

- Circle membership must be consent-backed.
- Ordinary Connections must not silently populate private Circles.
- Owners receive dedicated Circle-management controls separate from personal relationship-card management.
- Safety/privacy infrastructure remains part of the product proposition, not merely compliance work.

### Verified development evidence

- Circle creation, invitation, acceptance/decline, active membership, list-my-Circles behavior, and accepted-member spatial rendering have been exercised in the local Firebase/emulator test environment.
- The owner-facing Manage Test House membership view has been visually verified with two active members.
- Automated contract/analyzer checks have repeatedly passed during this milestone before visual emulator verification.

### Not yet traction

The above is product-development evidence. It is **not yet user traction**. Investor-facing traction should begin with closed-alpha/beta usage, retention, Circle adoption, invitation/acceptance behavior, conversation quality, safety outcomes, and willingness-to-pay evidence once privacy-reviewed instrumentation is ready.

## Near-term business milestone

The next business-relevant engineering proof is a complete Circle membership lifecycle:

**create → invite → accept → appear → manage → cancel/remove → disappear/update immediately.**

Once that loop is stable across Android and iOS, Circle becomes substantially stronger as a demo, beta-testing, customer-discovery, and investor-story asset.
