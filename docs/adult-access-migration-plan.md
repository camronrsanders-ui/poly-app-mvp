# Adult-access fail-closed migration and verification

**Status:** engineering draft — NOT DEPLOYED / NOT AUTHORIZED FOR STAGING OR PRODUCTION.
**Review branch:** `safety/adult-access-fail-closed-2026-10-10`.
**Scope:** adult-eligibility checks for member data in Cloud Functions and Firestore rules.

## Security decision

Member access requires all of:
- an existing account with `accountStatus == 'active'`;
- the trusted field `adultAccessApproved == true`;
- `termsAcceptedVersion == '2026-08-alpha-v1'`;
- `communityGuidelinesAcceptedVersion == '2026-08-v1'`.

A missing field, false/null approval or outdated policy acceptance must **deny member-data access**. A signed-in account must still be able to read its own minimal `users/{uid}` document for compliance routing, exit, and recovery. This is not equivalent to approval to use Discover, Circle, Messaging, or profile data.

## Legacy account handling — approval required before deployment

1. Review a *restricted count* of existing legacy active account records missing these fields. Do not export private identities or approval evidence to logs, CI, issue trackers, or screenshots.
2. Do **not** bulk-backfill `adultAccessApproved: true` based on account age, a profile age, prior participation, or old data. Prior self-attestation alone is not sufficient evidence of trusted approval.
3. Route each affected user through the existing trusted, App-Check-protected adult-assurance and current policy-acceptance flow. Record approval only through its reviewed callable; do not enable member access via client writes.
4. Confirm users who cannot finish verification can still access the self account marker and approved account-deletion/recovery exits, without reading member data.
5. Exercise account states: missing approval, false approval, null approval, stale Terms, stale Guidelines, suspended, banned, fully approved, and partial-migration retry. Check both backend callable rejection and Firestore direct-ID reads/writes.
6. Reconcile the UI error/recovery guidance for legacy users so the required compliance action is discoverable and not a silent account lockout.

## QA fixtures

The guarded `functions/scripts/seed_emulator.cjs` creates **fictional emulator identities** with synthetic accepted-policy fields. These records are never age verification evidence for real users. The seed workflow runs only inside the existing guarded emulator setup and must not be reused as a production migration script.

## Required gates

- [ ] Functions unit tests and TypeScript build pass on the exact review head
- [ ] Firestore security-rule adversarial tests pass, including missing approval and legitimate approved control case
- [ ] iOS and Android emulator journeys pass on the exact review head with synthetic fixtures
- [ ] Negative test without acceptance fixtures confirms unavailable native age signal fails closed
- [ ] Existing legacy user routing/reverification decision reviewed by product/privacy/safety owners
- [ ] Staging App Check and multi-user access verification performed after separately approved staging prerequisites
- [ ] Operator explicitly signs off on the rollout and on release/legal gates

**No approval to merge, deploy, change billing, or launch is implied by an automated PASS.** PR #21's pre-billing UI acceptance remains a separate manual gate.
