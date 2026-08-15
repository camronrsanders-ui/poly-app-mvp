# Polycircle — Age Assurance & App-Store UGC Compliance

**Last verified:** 2026-08-14  
**Status:** implementation foundation in progress; this document is not a claim of legal or app-store approval.

## Why this is a release gate

Polycircle is an adult dating/social product with user-generated profiles, messages, relationship descriptions, and media. Age assurance and UGC moderation therefore need to be treated as product/security architecture, not as a store-submission checkbox added at the end.

Primary platform sources reviewed for this work:

- Apple App Review Guidelines, Guideline 1.2 User-Generated Content: https://developer.apple.com/app-store/review/guidelines/
- Apple Declared Age Range: https://developer.apple.com/documentation/declaredagerange
- Google Play Age-Restricted Content and Functionality: https://support.google.com/googleplay/android-developer/answer/16302250
- Google Play UGC moderation requirements: https://support.google.com/googleplay/android-developer/answer/12923286
- Google Play Age Signals API: https://developer.android.com/google/play/age-signals/use-age-signals-api

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
- Where the platform API is unavailable or sharing is optional, the current pre-release fallback is self-attested date of birth. This fallback is explicitly tracked as a release risk rather than being described as verified age.

### Apple

- `com.apple.developer.declared-age-range` is present in `Runner.entitlements`.
- Flutter has a native bridge to Apple's Declared Age Range API when the framework/OS supports it.
- The request uses the age gate `18` and returns only range/status information to Flutter.
- Exact date of birth is not requested from Apple or stored by Polycircle.
- Older/unsupported iOS versions fail to the documented fallback path.

### Android

- Android includes Google Play Age Signals `0.0.4`.
- Flutter has a native bridge that requests age-sharing access before checking the age range.
- `VERIFICATION_REQUIRED` is treated as a blocking state.
- A shared range with an upper bound below 18 blocks access; an 18+ lower bound confirms adult status.

### UGC policy acceptance

Before onboarding/member access, the user must explicitly accept both:

- current pre-release Terms of Use version; and
- current Community Guidelines version.

Acceptance state and the age-assurance method/status are recorded on the user's account. Exact DOB is not recorded.

### Firestore boundary

New Firestore account documents explicitly begin with `adultAccessApproved=false`. Client member-data paths use the active-user helper, which denies these new accounts until the compliance record becomes approved. A temporary missing-field migration branch remains for old test/legacy documents and must be removed once migration/testing is complete.

### UGC controls already present

- in-app reporting;
- in-app blocking and block management;
- connection ending/unmatch safety behavior;
- protected profile-photo processing and moderator review;
- Safety Center and Community Guidelines;
- moderation runbook and privileged moderator foundations.

### UGC text prefilter

Profile free text, messages, and Circle-card free text now pass through a narrow pre-submit safety filter targeting severe high-confidence patterns such as direct violent threats and sexual/dating solicitation involving minors. The filter intentionally avoids broad identity/slur keyword lists because context, reclamation, education, and LGBTQ+/ENM terminology can create harmful false positives.

This client-side prefilter is **not** a substitute for trusted backend moderation. A modified client can bypass client code, so server-side text moderation/enforcement remains a public-beta gate.

## Required before Google Play distribution

- In Play Console, select **18 and over** as the only target age group.
- Enable Google's **Restrict Minor Access** functionality for the dating/matchmaking app. The in-app age gate and Play Age Signals API do not replace this store-level requirement.
- Complete/configure the Play Age Signals setup needed for the production application ID and test the real Play-delivered build.
- Test `SHARED`, `NOT_SHARED`, and `VERIFICATION_REQUIRED` behaviors on supported real devices/accounts.
- Review Play's Data safety, target audience, content-rating, UGC, sexual-content, and account-deletion disclosures against the shipping build.
- Replace debug signing with dedicated distribution signing before any distributed beta/release.

## Required before App Store distribution

- Enable/confirm Declared Age Range capability for the production App ID and signing profile in the Apple Developer account; a source-code entitlement alone is not production provisioning.
- Test Declared Age Range using Apple-supported sandbox/real-device flows on supported OS versions.
- Complete the current App Store Connect age-rating/social-capability questions accurately.
- Confirm the final app rating, UGC disclosures, contact/support information, and review notes describe the adult-only behavior and moderation tools accurately.

## UGC items still blocking a public beta

Apple's UGC guideline calls for filtering, reporting, blocking, timely response, and published contact information. Google Play similarly expects clear user policies, acceptance before UGC, accessible reporting/blocking, and ongoing moderation.

Polycircle still needs:

1. **Trusted text moderation/enforcement:** client prefiltering is only defense-in-depth. Add a backend moderation boundary for profile/message/public Circle text or an equivalent reviewed architecture before public beta.
2. **Moderator operations:** exercise queue ownership, response targets, escalation, appeals, and evidence handling with real staging data.
3. **Published support contact:** choose and publish a real business/support contact. Do not invent one in code or store metadata.
4. **Final Terms of Use:** replace the pre-release draft with counsel-reviewed public Terms.
5. **Final Privacy Policy:** publish a separate counsel-reviewed Privacy Policy covering actual data flows, retention, deletion, processors, age-assurance processing, and user rights.
6. **Content-rating/store declarations:** complete Apple/Google submission questionnaires using the actual shipping functionality.
7. **Adult-access migration:** migrate any legacy account documents, then remove the temporary Firestore missing-field allowance.
8. **Backend adult enforcement:** make every trusted callable that exposes/interacts with member data require the approved adult/compliance state, not only `accountStatus == active`.
9. **Tamper resistance on Android:** evaluate Play Integrity around age-signal flows as recommended by Google and threat-model how platform results are trusted.

## Privacy principles

- Do not store exact DOB unless a later legal/privacy review establishes a necessary purpose.
- Store the minimum evidence needed to know that the gate was completed: approval flag, policy versions, method/status, and timestamps.
- Do not expose age-assurance metadata in discovery/profile views.
- Do not treat self-attestation as “verified age.”
- Do not collect identity documents directly merely to imitate platform age-verification services.
- Minors must not receive a reduced dating experience inside Polycircle; the current product is adult-only, so confirmed minors are blocked.

## Release-language rule

Until the manual store configuration, real-device validation, final legal policies, backend enforcement, and moderation operations above are complete, describe this work as **“age-assurance and UGC-compliance foundation implemented”**, not “Polycircle is fully compliant.”
