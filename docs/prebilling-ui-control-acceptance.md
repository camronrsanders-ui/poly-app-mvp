# Polycircle — pre-billing visual & control acceptance matrix

**Status:** OPEN — manual/device evidence not yet signed off.  
**Baseline:** protected `main` at `fd239f169e230a029e1dc7f39faf4a88fc0cfa9b` (PR #4 merge).  
**Scope:** iOS and Android, local emulator first; staging/physical devices only after their separate prerequisites.  
**Security rule:** never switch on billing, deployment, disabled features, production Firebase or weakened App Check just to pass a UI check.

## Evidence standard

Record each check with: exact commit SHA; platform and OS/simulator; device dimensions and text scaling; light/dark theme; tester/date; path/action; actual result; screenshot or recording reference; and defect link. Use **PASS**, **FAIL**, **BLOCKED** (with why), or **NOT RUN**. A passing Flutter widget test or nine-stage emulator journey is **automated evidence**, not proof of manual interaction or visual parity.

For every **visible enabled** control, confirm a meaningful navigation, mutation, dialog, feedback or accessible disclosure; no inert tap target. Confirm disabled/busy states are visually and semantically disabled, destructive actions require confirmation, retry paths work, duplicate actions are prevented, and navigation/back leaves the app consistent. Avoid real-member data in screenshots.

## Acceptance matrix

All manual statuses are **NOT RUN** until verified independently on both platforms.

| ID | Screen/source area | Tap/action checks to observe | Manual iOS | Manual Android |
|---|---|---|---|---|
| UI-01 | Login (`auth/login_screen.dart`) | Sign in; invalid password/error; show/hide secret if present; recovery and signup routing; keyboard and return behavior | NOT RUN | NOT RUN |
| UI-02 | Signup (`auth/signup_screen.dart`) | Valid/invalid entry; password handling; duplicate submission; error recovery; route to compliance | NOT RUN | NOT RUN |
| UI-03 | Adult compliance (`compliance/compliance_gate_screen.dart`) | Terms and Guidelines separately; 18+ age check; Verify; failure copy; sign-out; no bypass or platform fail-open | NOT RUN | NOT RUN |
| UI-04 | Onboarding (`onboarding/onboarding_screen.dart`) | Every step, selector, validation, back/continue/save; persistence and failed-save retry; large text keyboard | NOT RUN | NOT RUN |
| UI-05 | Main shell (`main_shell.dart`) | Discover, Connections, Circle, Messages, Profile; selected/reselect state; Safety entry; back and app resume | NOT RUN | NOT RUN |
| UI-06 | Discover (`discover/discover_screen.dart`) | Connect/Pass, profile detail, filters/preferences, retry/empty/permission/blocked states; no double Like | NOT RUN | NOT RUN |
| UI-07 | Connections (`connections/connections_screen.dart`) | Spotlight/profile, find people, overflow menu, confirmed end/cancel, load/permission failure | NOT RUN | NOT RUN |
| UI-08 | Circle (`circle/my_circle_screen.dart`) | Orbital drag/spin, focus/cluster expansion, node select, alternative non-gesture path, navigation and privacy/redaction | NOT RUN | NOT RUN |
| UI-09 | Relationship manager (`circle/relationship_manager_screen.dart`) | Add/edit, valid/legacy enums, move up/down, deactivate, delete/cancel, retry; durable ordering | NOT RUN | NOT RUN |
| UI-10 | Messages (`messages/messages_screen.dart`) | List/open thread, unread/empty/error/loading, correct conversation return and refresh | NOT RUN | NOT RUN |
| UI-11 | Chat (`messages/chat_screen.dart`) | Type/send/draft retention, failed send retry, pagination, report/block/unmatch, attachments if enabled, return/back | NOT RUN | NOT RUN |
| UI-12 | Profile settings (`profile/profile_screen.dart`) | Each editable field and setting, photo routes, privacy, save failure, sign-out and account-exit paths | NOT RUN | NOT RUN |
| UI-13 | Self profile (`profile/self_profile_screen.dart`) | Owner sees self as others would within access rules, edit/return, media, overflow and accessible scroll | NOT RUN | NOT RUN |
| UI-14 | Member profile (`profile/profile_detail_screen.dart`) | Public detail/actions, photo permissions, block/report, connection-state affordances, denied/error states | NOT RUN | NOT RUN |
| UI-15 | Profile photos (`profile/profile_photos_screen.dart`) | Picker, preview, upload states, delete confirmation, retry, moderation status, no unprotected URL | NOT RUN | NOT RUN |
| UI-16 | Safety (`safety/safety_center_screen.dart`) | Help/report/blocked-members entries, block/unblock flows, negative and duplicate actions | NOT RUN | NOT RUN |
| UI-17 | Photo moderation (`safety/profile_photo_moderation_screen.dart`) | Staff-only access, pending/approve/reject, validation, denied/nonstaff, retry (test fixture only) | NOT RUN | NOT RUN |
| UI-18 | Shared Moments (`messages/shared_moments_screen.dart`) | **Feature gated OFF**: no exposed entry or creation path; no dormant control accidentally interactive | NOT RUN | NOT RUN |
| UI-19 | Shared Plans (`messages/shared_plans_screen.dart`) | **Feature gated OFF**: no exposed entry or creation path; no dormant control accidentally interactive | NOT RUN | NOT RUN |

Private Vault is **also gated OFF on client and server**; verify there is no reachable enabled entry or action. Do not enable it for this audit.

## Visual / device-equivalence passes

1. Repeat the above on **iOS and Android** at ordinary and enlarged text size. Check clipping, safe areas, status/nav bars, keyboard avoidance, scrolling, orientation behavior when supported, contrast, touch target size, and long localized-like strings.
2. Review Circle orbital motion and node legibility separately: single node, dense clusters, empty/loading, redacted/private nodes, gesture cancel, and screen-reader alternative.
3. Inspect the *actual native launcher icon* in the launcher/adaptive mask and the *native splash screen*, separately from in-app logos, using the previously approved branding—not a substitute.
4. Perform VoiceOver and TalkBack navigation, focus order, labels, toggles, error announcements, destructive-dialog focus, and alternative non-gesture controls.
5. Run network-loss/recovery, repeated taps during loading, back after failure, background/foreground, and relaunch persistence for critical flows.
6. Capture each issue with reproducible steps, expected/actual, severity (P0–P3), screenshot, OS/device, exact head and owner. **Any unresolved P0 or P1 affecting safety, access or basic navigation blocks pre-billing signoff.**

## Automated evidence already available

- Source-level audit counted **166 callback declarations** in 19 `lib/screens` files at the merged baseline; this is not 166 unique visible buttons or evidence of 166 successful taps.
- The static `tests/contracts/visible_controls_contract.test.mjs` check rejects obvious empty or placeholder callback bodies. It cannot detect wrong navigation, failed persistence, dead visual layers, inaccessible controls or dynamically injected actions.
- PR #4 pre-merge CI #1657 passed the local seeded nine-stage Android and iOS journeys. The post-merge `main` CI and dependency audit must be independently verified for any later head.

## Exit / explicit signoff

Do **not** mark this matrix complete until every applicable manual cell is PASS (or a justified BLOCKED entry is explicitly excluded from the approved scope), high-impact defects are resolved, and the user signs off on the intended experience. Physical-device and deployed staging/security/operations/legal gates remain separate and are documented in `docs/release-gates.md` and `docs/staging-acceptance-plan.md`. A merged foundation or green local CI alone does not authorize paid Firebase resources, deployment, external beta, or app-store launch.
