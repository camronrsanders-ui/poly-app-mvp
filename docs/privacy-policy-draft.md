# Polycircle Privacy Policy — Internal Draft

**Status: NOT FOR PUBLICATION.** This draft must be reviewed for legal, jurisdictional, app-store, and implementation accuracy before release. Replace every bracketed placeholder before publication.

Last internal review: 2026-08-10

## 1. Scope

This draft describes the intended privacy practices for Polycircle, an adults-only dating/community product for polyamorous, ethically non-monogamous, and related relationship structures. It should describe shipped behavior only; a feature must not be promised here merely because it exists in a roadmap.

## 2. Operator information

- Operator legal name: `[REQUIRED]`
- Privacy contact: `[REQUIRED]`
- Mailing address, if legally required: `[REQUIRED]`
- Applicable representative/DPO details, if required: `[REQUIRED]`

Do not publish until these fields are complete.

## 3. Information members provide

Current account/profile design can include:

- email address and authentication information handled through Firebase Authentication;
- display name and age;
- city and region;
- biography and headline;
- gender identity, pronouns, orientation, and self-described identity tags;
- relationship structure/status and whether the member is partnered;
- interests, connection intentions, and free-text “looking for” information;
- private discovery preferences such as age range, preferred structures, preferred intentions, and distance preference;
- relationship/Circle cards, including optional names and free-text notes entered by the account owner;
- profile photos submitted through the protected media workflow;
- messages exchanged with active connections;
- blocks and safety reports.

A relationship card reflects the account owner’s description. Naming another person does not verify that person’s identity, relationship, or consent.

## 4. Information generated through use

Polycircle may maintain operational records needed to run the service, such as:

- account creation and activity timestamps;
- likes, passes, matches, and connection lifecycle state;
- conversation/message timestamps and read state;
- block/unblock and report records;
- rate-limit/security records;
- profile-photo processing/moderation status;
- minimal deletion-recovery state when an account deletion cannot finish in one attempt.

Application analytics must not log message bodies, report details, email addresses, private relationship-card content, or private identity/discovery fields.

## 5. Discovery and profile visibility

Full profile documents contain private preference fields and are not intended to be readable directly by other members. Cross-user Discover/Connections views are produced by trusted backend functions that return a sanitized display-safe field set.

Discovery preferences are intended to be private and applied on the trusted backend. Profiles can be hidden from new discovery through profile visibility/open-to-connections controls.

Polycircle currently uses coarse city/region profile location. Exact location is not a default public profile field.

## 6. Relationship Circle privacy

Full relationship-card documents are owner-only. Other members receive only a trusted view permitted by the owner’s Circle/card visibility settings. Free-text names/notes can be redacted based on those settings.

Relationship descriptions are user-generated statements, not platform verification.

## 7. Messages

Messages are available only within an active, unblocked conversation between the participants under the current security rules. Ending a connection or blocking closes current chat access.

The final retention period for messages after account deletion is **not yet approved**. The release decision must be recorded in `docs/data-retention-matrix.md` and this section must be updated before publication.

## 8. Profile photos

The intended protected profile-photo flow uses quarantine, validation, trusted image re-encoding, metadata stripping through re-encoding, moderation status, and protected short-lived delivery rather than permanent public Storage URLs.

This workflow must be validated on staging/real devices before external beta. This draft must not imply production validation until that release gate passes.

## 9. Private Vault

Private Vault is currently disabled in both the client and trusted backend and must not be described publicly as an available feature.

If enabled in a future release, this policy requires a separate review covering sensitive/intimate media, explicit request/accept consent, per-recipient sharing, revocation, moderation, evidence handling, retention, deletion, and app-store/jurisdiction requirements.

## 10. Safety reports and moderation

Members can submit safety reports. Reports may include reporter/reported account identifiers, a reason, optional details, timestamps, and moderation state. Access must be limited to the reporting member where appropriate and trusted moderation systems/operators.

Final report/evidence retention periods remain a release decision. Safety/legal preservation must be narrowly scoped, documented, and separated from public identity where practical.

## 11. Blocks

Blocking is a safety control. A block terminates applicable interaction and current connection/chat/private-media access. Members can manage blocks. Unblocking does not automatically restore an ended match, conversation, or private-media permission.

## 12. Account deletion

Account deletion is a trusted backend workflow, not a series of client-side deletes. It currently requires an explicit confirmation and recent authentication.

The design pauses the account first, removes/tombstones applicable member data, cleans owned protected Storage paths, and deletes Authentication only after privacy-critical cleanup succeeds. If cleanup fails before Authentication deletion, the account remains paused with a minimal recovery marker so the member can sign in again and retry. Once Authentication is removed, a failure to delete the final Firestore marker may leave only a minimal non-profile tombstone for operational cleanup.

Deletion behavior still requires staging end-to-end and partial-failure validation before public release.

## 13. Service providers

Current implementation uses Google Firebase/Google Cloud services for authentication, database, functions, storage, and related infrastructure. The final public policy must name applicable processors/services accurately based on the production architecture and signed terms at launch time.

Do not add analytics, advertising, crash reporting, or other processors to this section unless they are actually integrated and reviewed for sensitive-data handling.

## 14. Security

Current engineering controls include restrictive Firestore/Storage rules, backend-controlled sensitive state transitions, App Check wiring, rate limits, protected media paths, short-lived media delivery, automated adversarial rules tests, and CI checks.

No security measure can guarantee absolute security. Public language must not claim that screenshots, device compromise, recipient copying, or all unauthorized disclosure can be technically prevented.

## 15. Children

Polycircle is intended only for adults age 18 or older. The product must not knowingly permit minors to create dating accounts. Sexual content involving minors is prohibited.

Age-gating and app-store policy requirements must be reviewed before distribution.

## 16. Member choices and rights

Depending on jurisdiction, members may have rights to access, correct, delete, restrict, or obtain a copy of personal information and to appeal certain moderation decisions. The production process, identity verification, response timelines, and contact path for these rights must be defined before publication.

## 17. International use

International transfer/location language must be added based on the operator’s legal entity, hosting configuration, launch countries, and applicable data-processing agreements. Do not infer or publish this section until those facts are known.

## 18. Retention

The authoritative engineering decision tracker is `docs/data-retention-matrix.md`. Before public release, every unresolved retention item must have an approved duration/rationale and be reflected consistently in this policy and implementation.

## 19. Changes

The public policy should state how material changes are communicated and the effective date. Product changes that expand sensitive-data collection or sharing require privacy review before shipping, not only a later policy edit.

## Publication checklist

- Fill operator/contact/jurisdiction placeholders.
- Finalize message/report/media/security-log/backup/inactive-account retention.
- Validate account deletion end-to-end on staging.
- Validate profile-media workflow on staging and real devices.
- Confirm final processor/subprocessor list.
- Complete access/export request workflow.
- Confirm age-gating and launch-country requirements.
- Review Terms and Community Guidelines for consistent language.
- Obtain appropriate legal/privacy review.
