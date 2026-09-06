# Polycircle Staging & Real-Device Acceptance Plan

Run this plan after a staging Firebase project can deploy trusted Functions. Emulator success is a prerequisite, not a substitute.

## Test environment prerequisites

- Dedicated staging Firebase/Google Cloud project identified.
- iOS and Android staging apps use the intended bundle/application IDs.
- Auth, Firestore, Storage, Functions, indexes, and rules deployed from the reviewed commit.
- App Check staging providers configured.
- Test-only accounts/data; no production member data.
- Billing budget/alerts configured before sustained testing.
- Private Vault client flag and server gate remain OFF.

Record for every run:

- commit SHA;
- staging project ID;
- iOS/Android app version/build;
- device/OS versions;
- tester/date;
- pass/fail notes and defect links.

## Journey A — New account

1. Install fresh app.
2. Sign up with new email/password.
3. Confirm trusted `users` record creation.
4. Complete onboarding.
5. Verify account cannot mark onboarding complete without a profile.
6. Reach main shell.
7. Relaunch and verify session routes correctly.
8. Sign out/sign back in.

Negative checks:

- invalid credentials;
- network interruption during signup bootstrap;
- network interruption during onboarding save;
- under-18 age rejected;
- malformed/overlong profile fields rejected.

## Journey B — Discover

1. Seed several eligible and ineligible staging accounts.
2. Confirm only public/open/active/reciprocally compatible candidates appear.
3. Verify private preference fields never appear in callable response/client debug output.
4. Pass one profile; confirm it remains out of Discover.
5. Like one profile; confirm it remains out of Discover.
6. Form a mutual match; confirm both leave Discover and connection appears.
7. End match; confirm it does not silently resurface.
8. Block another candidate; confirm neither direction can interact/discover as applicable.

Negative checks:

- direct callable with arbitrary UID;
- malformed limit;
- App Check missing/invalid;
- rate-limit exhaustion;
- inactive/hidden target direct Like attempt.

## Journey C — Connections and profiles

1. Open Connections.
2. Verify sanitized profile data only.
3. Open existing connection profile.
4. Verify no duplicate Connect action.
5. Confirm permitted profile photos use protected delivery.
6. Verify Circle details honor visibility/redaction.
7. End connection and verify list updates.

## Journey D — Messaging

1. Open/create conversation from active match.
2. Send messages both directions.
3. Verify timestamps are server-generated.
4. Verify read state updates only for participants.
5. Simulate send failure and verify draft text remains.
6. Block from chat; verify chat closes and future reads/writes fail.
7. End connection; verify old chat cannot be accessed under current policy.
8. Attempt direct-ID message access as nonparticipant.

## Journey E — Circle

1. Add relationship card.
2. Edit label/type/status/note/visibility.
3. Reorder several cards.
4. Deactivate/delete a card.
5. Verify owner can read full data.
6. Verify unrelated/matched viewers cannot directly read full Firestore cards.
7. Verify trusted public/matches-only/unnamed/private behavior.
8. Verify legacy/unknown enum fixture does not crash editor.

## Journey F — Safety

1. Report profile.
2. Report from chat.
3. Block profile.
4. Open Safety Center > Manage blocked members.
5. Unblock and verify prior match/chat/private permissions are not automatically restored.
6. Verify block/unmatch revokes Private Vault request/grant state even while Vault remains disabled.
7. Confirm report details are not exposed through ordinary client reads.

## Journey G — Profile photos

1. Select supported image.
2. Begin signed upload.
3. Confirm quarantine path/object.
4. Validate size/type rejection cases.
5. Verify trusted re-encode produces JPEG and strips original metadata.
6. Verify processed photo waits for moderation.
7. Approve through trusted moderator path.
8. Verify owner management/status.
9. Verify permitted remote viewer receives short-lived URL only.
10. Verify hidden/blocked/nonpermitted viewer denied.
11. Delete photo and verify metadata/object cleanup.

Include malformed/corrupt/high-pixel-count test files without exposing personal test media.

## Journey H — Account deletion

1. Attempt with stale auth; confirm recent-auth failure and fresh-login path.
2. Retry with fresh auth.
3. Verify account becomes immediately non-discoverable/paused.
4. Verify cards/likes/passes/blocks/profile-media metadata/private-media metadata are cleaned as designed.
5. Verify active matches/conversations close without falsifying last-message chronology.
6. Verify protected Storage prefixes are removed before Auth deletion.
7. Inject a Storage cleanup failure; verify Auth remains and account routes to deletion recovery.
8. Sign in again and finish deletion.
9. Verify Auth deletion and final user-record cleanup/minimal tombstone behavior.
10. Re-run deletion cleanup logic against partially cleaned data for idempotency.

## Journey I — App Check

For every sensitive callable class:

- valid staging app succeeds;
- missing/invalid App Check rejected;
- valid Auth but invalid App Check rejected;
- simulator debug token works only in intended development context;
- production providers verified on real devices before external beta.

## Journey J — Real-device platform checks

### iOS

- clean install;
- launcher icon/splash branding;
- signup/login/onboarding;
- App Check App Attest/DeviceCheck behavior;
- photo picker/upload;
- background/foreground transitions;
- network loss/recovery;
- VoiceOver/Dynamic Type checks.

### Android

- native Firebase configuration;
- clean install;
- launcher/adaptive icon review;
- signup/login/onboarding;
- Play Integrity App Check behavior;
- photo picker/upload;
- background/foreground transitions;
- network loss/recovery;
- TalkBack/font-size checks.

## Exit criteria

Closed/internal alpha may proceed only when the scoped acceptance journeys pass for the intended environment and no unresolved P0 safety/security issues remain.

External beta additionally requires the release gates, policy/legal decisions, moderation operations, retention decisions, backup/restore readiness, accessibility review, and protected-media validation described elsewhere in `docs/`.
