# Polycircle — Monetization Architecture

**Last verified:** 2026-08-15  
**Status:** architecture foundation only. Real billing, real subscriptions, production ads, and production ad-consent SDKs remain **OFF**.

This document is a product/security plan, not tax, legal, accounting, App Store approval, or Google Play approval advice. Platform rules change; re-verify the current primary documentation before enabling production monetization.

Primary platform references reviewed for this foundation:

- Apple App Review Guidelines — payments/subscriptions: https://developer.apple.com/app-store/review/guidelines/
- Apple StoreKit restore guidance: https://developer.apple.com/documentation/storekit/restoring-purchased-products
- Apple App Store Server API: https://developer.apple.com/documentation/appstoreserverapi
- Google Play Billing integration: https://developer.android.com/google/play/billing/integrate
- Google Play Billing security: https://developer.android.com/google/play/billing/security
- Google Play backend integration: https://developer.android.com/google/play/billing/backend
- Google UMP / ad privacy: https://developers.google.com/admob/android/privacy and https://developers.google.com/admob/ios/privacy
- AdMob app-ads.txt: https://support.google.com/admob/answer/9363762

## Product principle

Polycircle should monetize **more control and capability**, not basic dignity, safety, consent, or privacy.

The following must not become paid-only features:

- blocking;
- reporting;
- ending a connection/unmatching for safety;
- account deletion;
- age-assurance controls;
- basic privacy controls;
- consent and Community Guidelines access;
- Safety Center / public community resources;
- core profile creation;
- basic messaging with an active connection; and
- protection from harassment, exploitation, or abuse.

## Working subscription model

The current tier names and capability bundles are **testing hypotheses**, not final prices or promises.

### Free

Core Polycircle remains useful without payment. Free is the default whenever subscription state is missing, malformed, expired, unverifiable, or temporarily unavailable.

### Plus — working hypothesis

Potential capability flags currently modeled for internal testing:

- advanced discovery controls;
- a higher Like allowance;
- rewind/undo;
- incognito-style controls;
- ad-free experience.

### Premium — working hypothesis

Includes the Plus capability set plus a placeholder `advanced_circle` entitlement for future enhanced Circle tools. The exact product should be validated with members before release rather than assumed in advance.

No price is hard-coded in the app. Store product metadata must remain the display source of truth for localized price/currency when real billing is added.

## Current code architecture

### Client

`lib/config/monetization_config.dart`

- `billingPurchaseFlowEnabled=false`
- `advertisingSdkEnabled=false`
- defines Free / Plus / Premium testing tiers and capability flags
- supports a **debug-build-only** `POLYCIRCLE_DEBUG_SUBSCRIPTION_TIER` preview override
- release/profile builds ignore that debug override

The debug override is UI-development convenience only. It is never written to Firebase and must never authorize a trusted paid backend operation.

`lib/services/entitlement_service.dart`

- obtains normal entitlement state from the App-Check-protected `getMyEntitlements` callable;
- does not write subscription state to Firestore;
- fails closed to Free when entitlement lookup is unavailable.

`lib/services/ad_policy.dart`

- no ad SDK is installed;
- only a future Discover intermission is currently eligible for advertising;
- messages, Circle, Safety Center, reports, blocking, age assurance, account deletion, and Private Vault are protected no-ad surfaces;
- sensitive member information is explicitly prohibited as ad-targeting input.

### Trusted backend

`functions/src/monetization.ts` exposes a read-only `getMyEntitlements` callable with App Check enforcement and a valid active-account requirement.

The entitlement lookup intentionally does **not** require acceptance of the latest participation-policy version. A future Terms/Community Guidelines update must not hide an already-paid subscription or obstruct a future manage/cancel-subscription path. Actual paid member features can and should still enforce current adult/community participation eligibility at their own trusted backend boundary.

The callable reads backend-only `_billing_entitlements/{uid}` state. There is currently **no production writer** for this collection. Real StoreKit / Play Billing verification must be implemented before paid states can legitimately exist.

`functions/src/monetization_entitlements.ts` fails closed. Paid access is returned only when all of the following are true:

- tier is an allowed paid tier;
- source is `app_store` or `google_play`;
- status is `active` or `grace_period`;
- `storeVerified=true` was set by trusted future server verification; and
- `accessUntilMs` is still in the future.

Raw receipts, purchase tokens, original transaction IDs, billing history, and prices are not returned to the client entitlement response.

When a paid feature later changes trusted backend behavior, that backend operation must independently check the current entitlement. A client-visible `capabilities` array is **not authorization**.

## Future purchase flow

The intended flow is:

1. App displays products/prices returned by StoreKit or Google Play Billing.
2. User completes purchase through the platform billing UI.
3. Client sends only the platform transaction evidence needed for verification to a trusted Polycircle backend endpoint.
4. Backend verifies directly with Apple/Google.
5. Backend binds the verified transaction to the correct Polycircle account and prevents token/transaction reuse.
6. Backend writes normalized `_billing_entitlements/{uid}` state.
7. Client refreshes `getMyEntitlements`.
8. Trusted paid backend features independently enforce entitlement when used.

Never accept `tier=Premium`, `paid=true`, a product ID, or a client-computed expiration date as proof of purchase.

## Subscription states that must be designed before launch

Real billing work must cover at least:

- initial purchase;
- pending purchase;
- active subscription;
- renewal;
- billing grace period;
- expiration;
- cancellation at period end;
- refund/revocation;
- upgrade and downgrade;
- restore purchases / new device;
- account switching;
- duplicate/replayed transaction evidence;
- lost network response after a successful store purchase; and
- server notification reconciliation.

The backend record should be derived from current store truth, not permanently trust an old client callback.

## Apple requirements before enabling paid iOS features

- Create real products/subscription groups in App Store Connect.
- Use StoreKit for digital features sold in-app unless a reviewed platform/storefront exception is intentionally adopted.
- Provide clear subscription value, duration, localized price, renewal terms, and management/cancellation information.
- Provide a user-visible Restore Purchases path where applicable.
- Verify transactions using trusted Apple transaction/server data before granting backend entitlement.
- Configure App Store Server Notifications / reconciliation appropriate to the final design.
- Test purchases, renewal, cancellation, restore, refund/revocation, upgrade/downgrade, and interrupted flows in Apple's sandbox/TestFlight environments.
- Describe paid functionality accurately in App Review notes and store metadata.

## Google Play requirements before enabling paid Android features

- Create subscription/base-plan/offer products in Play Console.
- Integrate the then-current supported Play Billing Library.
- Send purchase tokens to the backend and verify them with the Google Play Developer API before granting entitlement.
- Prevent purchase-token replay/account swapping and bind purchases to the expected Polycircle account.
- Grant access only for valid purchased states and correctly acknowledge eligible purchases.
- Implement Real-time Developer Notifications / backend reconciliation appropriate to the final design.
- Test pending, active, renewal, cancellation, restore, grace, expiration, refund/revocation, and upgrade/downgrade behavior with Play test accounts.

## Advertising position

Subscriptions are the preferred primary revenue model. Advertising is secondary and should not create an incentive to exploit intimate member data.

### Data that must not be used to build Polycircle ad-targeting profiles

- sexual orientation;
- gender identity;
- relationship structure/status;
- Circle graph or relationship-card contents;
- profile age;
- precise location;
- race or ethnicity;
- religion;
- political beliefs;
- private messages;
- blocks or reports;
- health/HIV information;
- intimate-media activity;
- age-assurance metadata; or
- inferences drawn from those categories.

Future ads should begin with contextual/non-personalized approaches rather than sensitive behavioral targeting.

### Approved/prohibited placements

Currently the only coded future-eligible placement is a clearly labeled **Discover intermission**.

Ads must not appear in:

- private chats;
- Safety Center;
- report/block flows;
- age assurance;
- account deletion;
- Private Vault;
- Circle relationship details; or
- other crisis/safety/privacy workflows.

Sponsored content must be unmistakably labeled and must not impersonate a member profile.

### Consent and SDK initialization

No production ad request should occur until the shipping privacy/consent layer says ads may be requested. If UMP or another consent platform is used, the implementation must check the current consent state before requesting ads and provide any required privacy-options entry point.

An ad-free paid entitlement must suppress ad requests, not merely hide a rendered ad after its SDK has already received sensitive context.

### Ad network controls

Before production:

- configure sensitive-category and advertiser blocking controls;
- review actual ads during testing;
- decide whether personalized advertising is permitted at all;
- complete Apple privacy/ATT analysis for the exact SDK/data flow;
- complete Google Play Data safety disclosures;
- publish a real developer website; and
- publish/verify `app-ads.txt` when an ad network requires it.

Do not add placeholder publisher IDs, production ad unit IDs, or invented business contact details to source control.

## Release gates

### Gate M0 — architecture only (current target)

- real purchase flow OFF;
- real ad SDK OFF;
- no store product IDs required;
- no production publisher/ad unit IDs;
- debug subscription preview ignored outside debug builds;
- client cannot write trusted entitlement state;
- missing/invalid/expired entitlement resolves to Free;
- entitlement response does not expose raw store transaction evidence;
- safety/privacy features remain outside paid capability flags.

### Gate M1 — sandbox billing

Before any tester can spend money:

- final candidate paid capabilities documented;
- Apple/Google products configured in sandbox/test environments;
- server-side purchase verification implemented;
- replay/account-binding protections implemented;
- entitlement cleanup/data export/retention behavior decided;
- restore purchases implemented;
- subscription state transitions tested;
- subscription visibility and manage/cancel access do not require accepting a newly revised participation policy;
- no production charges enabled.

### Gate M2 — production subscriptions

Before production billing:

- pricing and trial/offer strategy approved;
- final Terms/Privacy billing disclosures reviewed;
- customer support/refund escalation process operational;
- Apple/Google server notification reconciliation operational;
- subscription analytics use privacy-safe events;
- App Store/Play metadata accurately describes paid features;
- taxes/entity/banking/store agreements handled outside source code;
- production product IDs and signing/configuration validated.

### Gate A1 — test ads

- consent layer implemented before any ad request;
- only test ad units used;
- no sensitive profile/message/Circle/report data sent as targeting parameters;
- protected no-ad surfaces verified;
- paid ad-free state suppresses requests;
- ad category controls reviewed.

### Gate A2 — production ads

- business decision confirms ads are still appropriate after beta feedback;
- privacy/legal review covers the exact ad SDK and processors;
- ATT/consent behavior validated where applicable;
- Data safety/App Privacy disclosures match runtime behavior;
- developer website and app-ads.txt are live/verified where required;
- production ad unit IDs/configuration are supplied outside inappropriate public source locations;
- moderation/support process exists for inappropriate ads.

## Decisions intentionally deferred

The following should not be guessed before user testing:

- final monthly/annual prices;
- whether Premium is needed in addition to Plus;
- free trial duration;
- exact Like limits;
- whether boosts/one-time purchases belong in Polycircle;
- whether advertising is worth the privacy/trust tradeoff at all;
- which ad network, if any, should be used; and
- revenue projections based on conversion/retention data we do not yet have.

The first beta should teach us what people value before monetization pressure determines the product.
