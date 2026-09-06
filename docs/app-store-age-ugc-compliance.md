# Polycircle — Age Assurance & App-Store UGC Compliance

**Last verified:** 2026-08-15  
**Status:** age-assurance and UGC-compliance foundation implemented and under automated validation; this document is **not** a claim of legal advice, App Store approval, Google Play approval, or full regulatory compliance.

## Why this is a release gate

Polycircle is an adult dating/social product with user-generated profiles, messages, relationship descriptions, and media. Age assurance and UGC moderation therefore need to be treated as product/security architecture, not as a store-submission checkbox added at the end.

Primary platform sources reviewed for this work:

- Apple App Review Guidelines, Guideline 1.2 User-Generated Content: https://developer.apple.com/app-store/review/guidelines/
- Apple Declared Age Range: https://developer.apple.com/documentation/declaredagerange
- Google Play Age-Restricted Content and Functionality: https://support.google.com/googleplay/android-developer/answer/16302250
- Google Play UGC moderation requirements: https://support.google.com/googleplay/android-developer/answer/12923286
- Google Play Age Signals API: https://developer.android.com/google/play/age-signals/use-age-signals-api
- Google Play Age Signals 0.0.4 release notes: https://developer.android.com/google/play/age-signals/release-notes

Platform policies and laws change. Re-verify the primary sources before every public-store submission.

## Implemented foundation

### Adult-access gate

- New accounts start with `adultAccessApproved=false`.
- The signed-in session routes through an adult/policy compliance screen before onboarding or the member shell.
- The screen asks for date of birth with a date picker rather than a simple “Are you 18?” checkbox.
- The app calculates 18+ eligibility locally and does **not** persist the exact birth date.
- A platform signal that confirms the person is under 18 blocks access.
- A platform response that says verification is required blocks progress until the store/device verification is resolved.
- In a region where the native platform marks age assurance as required, failure/declined sharing cannot silently downgrade to self-attestation.
- Where the platform API positively indicates optional/non-shared behavior, the current pre-release fallback is self-attested date of birth. This fallback is explicitly tracked as a release risk rather than being described as verified age.
- When the app cannot determine whether mandatory platform assurance applies because a native assurance check itself fails, the current implementation fails closed and requires retry rather than silently assuming a nonregulated fallback.

### Apple

- `com.apple.developer.declared-age-range` is present in `Runner.entitlements`.
- Both Flutter iOS build configurations set `CODE_SIGN_ENTITLEMENTS=Runner/Runner.entitlements`, so Debug, Release, and Profile target builds inherit the entitlement file.
- Flutter has a native bridge to Apple's Declared Age Range API when the framework/OS supports it.
- The request uses the age gate `18` and returns only range/status information to Flutter.
- Exact date of birth is not requested from Apple or stored by Polycircle.
- Older/unsupported iOS versions fail to the documented fallback path where platform assurance is not known to be mandatory.
- The bridge uses the OS availability required by the currently compiled Apple API, rather than assuming every iOS 26 build exposes the same age-feature surface.
- CI has successfully compiled the current iOS native age-assurance bridge after correcting availability and Flutter registrar handling.

### Android

- Android includes Google Play Age Signals `0.0.4`.
- Flutter has a native bridge that first calls `requestAgeSignalsAccess()` and only calls `checkAgeSignals()` after Play returns `SHARED`.
- `VERIFICATION_REQUIRED` is treated as a blocking state.
- Play Age Signals 0.0.4 no longer supports the older `userStatus` response model; the implementation uses the supported `ageRangeSource`, `ageLower`, and `ageUpper` response fields instead.
- A shared range with an upper bound below 18 blocks access; a shared lower bound of 18 or greater confirms adult status.
- A shared result that remains ambiguous around the 18+ boundary fails closed rather than being interpreted as adult.
- Failures while determining access/sharing requirements or retrieving an already-shared signal fail closed instead of silently downgrading to self-attestation.
- The app does not use `ageRangeSource` alone as proof of adulthood; the age bounds determine the 18+ decision.
- CI must continue compiling the Android debug APK after any Age Signals bridge change; real Play-delivered validation remains separate.

### UGC policy acceptance

Before onboarding/member access, the user must explicitly accept both:

- current pre-release Terms of Use version; and
- current Community Guidelines version.

Acceptance state and the age-assurance method/status are recorded on the user's account. Exact DOB is not recorded.

### Firestore adult-compliance boundary

New Firestore account documents explicitly begin with `adultAccessApproved=false`. For accounts using the new compliance schema, normal member-data access requires all of the following:

- active account status;
- `adultAccessApproved=true`;
- the exact current Terms version; and
- the exact current Community Guidelines version.

A temporary missing-field migration branch remains for old test/legacy account documents so existing local QA fixtures do not become unusable while the migration is prepared. This compatibility allowance is a **public-release blocker** and must be removed after migration/testing.

### Trusted member-callable boundary

The shared trusted backend eligibility helper now protects the main member-facing callable surfaces, including:

- Discover candidate retrieval;
- Like/match flow;
- Pass;
- conversation creation;
- Connections listing;
- trusted Circle views;
- report/block/unblock/end-connection safety actions; and
- member profile-photo upload, confirmation, protected access, and listing flows.

The helper requires an active account plus current adult/policy approval for new-format accounts, and the relevant transaction paths re-check target eligibility where a target account is part of authorization.

Two deliberate exceptions should remain available even when a member does not accept a newer policy version:

- **account deletion**, so declining new Terms cannot trap a user in the service; and
- **own-data access/export**, subject to its existing authentication/rate-limit controls, because privacy/data-access rights should not depend on accepting new community participation terms.

Privileged moderator/admin operations are separate operator-security paths and should be governed by least-privilege claims, audit, and operational controls rather than being treated as normal member access. Private Vault remains server/client gated OFF and is not counted as a released member surface.

### UGC controls already present

- in-app reporting from profiles and chats;
- message-level reporting from chat by pressing and holding another member's message;
- trusted validation that a reported message belongs to the stated conversation, was sent by the reported account, and came from a conversation the reporter participated in;
- reports store a content reference rather than automatically copying the reported message text into report details;
- moderator report listings expose the validated content type/reference needed to investigate the correct item;
- in-app blocking and blocked-member management;
- connection ending/unmatch safety behavior;
- report reasons for harassment, threats/violence, child-safety or underage concerns, sexual content/solicitation, non-consensual content, hate speech, fake profiles, scams/spam, misrepresentation, and other concerns;
- protected profile-photo processing and moderator review;
- Safety Center and Community Guidelines; and
- moderation runbook and privileged moderator foundations.

Report details are intentionally **not** passed through the normal posting filter. A member must be able to describe threatening, exploitative, hateful, or sexual material when submitting evidence/context for moderation.

### UGC text prefilter and Firestore enforcement

Profile free text, messages, and Circle-card free text pass through a narrow pre-submit safety filter targeting severe high-confidence patterns such as direct violent threats and sexual/dating solicitation involving minors. The filter intentionally avoids broad identity/slur keyword lists because context, reclamation, education, survivor-support, and LGBTQ+/ENM terminology can create harmful false positives.

The same narrow severe-content categories are also enforced independently in Firestore Security Rules for direct client writes to:

- profile display/free-text fields;
- Circle relationship-card display/free-text fields; and
- text messages.

This means a modified Flutter client cannot bypass the posting filter merely by calling Firestore directly. Firebase emulator tests exercise prohibited threat/minor-solicitation writes for profile, Circle, and chat paths.

This is still **not a complete moderation system**. Firestore Rules are deterministic pre-post controls, not contextual human moderation, and trusted Admin SDK/server code bypasses client Security Rules by design. Public release therefore still requires reviewed moderator operations, report response targets, escalation/evidence procedures, and continuing review of every server-generated UGC path.

## Required before Google Play distribution

- In Play Console, select **18 and over** as the only target age group.
- Enable Google's **Restrict Minor Access** functionality for the dating/matchmaking app. The in-app age gate and Play Age Signals API do not replace this store-level requirement.
- Complete/configure the Play Age Signals setup needed for the production application ID and test the real Play-delivered build.
- Test `SHARED`, `NOT_SHARED`, and `VERIFICATION_REQUIRED` behaviors on supported real devices/accounts, including adult 18+ ranges, minor ranges, supervised ranges, and ambiguous/error behavior.
- Verify the shipping implementation against the then-current supported Play Age Signals version; do not reintroduce the removed 0.0.3 `userStatus` model while using 0.0.4+.
- Review Play's Data safety, target audience, content-rating, UGC, sexual-content, and account-deletion disclosures against the shipping build.
- Replace debug signing with dedicated distribution signing before any distributed beta/release.
- Threat-model the trust placed in age signals and evaluate Play Integrity or equivalent platform anti-tamper protections appropriate to the production design.

## Required before App Store distribution

- Enable/confirm Declared Age Range capability for the production App ID and signing profile in the Apple Developer account; a source-code entitlement alone is not production provisioning.
- Test Declared Age Range using Apple-supported sandbox/real-device flows on supported OS versions.
- Complete the current App Store Connect age-rating/social-capability questions accurately.
- Confirm the final app rating, UGC disclosures, contact/support information, and review notes describe the adult-only behavior and moderation tools accurately.

## UGC / age items still blocking public distribution

1. **Moderator operations:** exercise queue ownership, response targets, escalation, appeals, and evidence handling with real staging data. Automated filtering does not replace timely human review.
2. **Published support contact:** choose and publish a real business/support contact. Do not invent one in code or store metadata.
3. **Final Terms of Use:** replace the pre-release draft with a reviewed public Terms document before public distribution.
4. **Final Privacy Policy:** publish a separate reviewed Privacy Policy covering actual data flows, retention, deletion, processors, age-assurance processing, and user rights.
5. **Content-rating/store declarations:** complete Apple/Google submission questionnaires using the actual shipping functionality.
6. **Adult-access migration:** migrate any legacy account documents, then remove the temporary Firestore/backend missing-field allowance.
7. **Remaining callable audit:** keep auditing every new or existing member-facing callable so it either uses the centralized compliance helper or has a documented privacy/safety reason not to. Account deletion and own-data access are intentional exceptions.
8. **Server/Admin UGC review:** continue to audit any server-generated or Admin-SDK UGC write paths because Firestore client rules do not apply to Admin SDK writes.
9. **Real platform validation:** production/sandbox Apple age-range and Play Age Signals behaviors must be validated on real supported devices/store-delivered builds.
10. **Android tamper resistance:** evaluate Play Integrity around production age-signal flows and document the threat model.
11. **Report evidence lifecycle:** finalize how referenced messages/content are retained, redacted, or deleted when a report is open, an account is deleted, or the underlying content is removed.

## Privacy principles

- Do not store exact DOB unless a later legal/privacy review establishes a necessary purpose.
- Store the minimum evidence needed to know that the gate was completed: approval flag, policy versions, method/status, and timestamps.
- Do not expose age-assurance metadata in discovery/profile views.
- Do not treat self-attestation as “verified age.”
- Do not collect identity documents directly merely to imitate platform age-verification services.
- Minors must not receive a reduced dating experience inside Polycircle; the current product is adult-only, so confirmed minors are blocked.
- Do not require acceptance of new participation terms merely to let a user delete their account or exercise a legitimate own-data access process.
- Do not silently duplicate harmful message text into report metadata when a stable validated content reference is enough for moderation review.

## Release-language rule

Until manual store configuration, real-device validation, final legal policies, legacy-account migration, and operational moderation are complete, describe this work as **“age-assurance and UGC-compliance foundation implemented”**, not “Polycircle is fully compliant.”
