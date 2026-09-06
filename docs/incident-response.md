# Polycircle Security & Privacy Incident Response

This runbook is for engineering/operations readiness. It does not replace legal, insurance, law-enforcement, platform, or regulatory advice.

## Goals

1. Protect members from ongoing harm.
2. Contain unauthorized access or disclosure quickly.
3. Preserve only the evidence necessary to understand the incident.
4. Avoid spreading sensitive member data during investigation.
5. Restore trusted service safely.
6. Meet notification/legal obligations after qualified review.

## Severity

### P0 — Critical
Examples: confirmed unauthorized access to private messages/media at scale; authentication bypass; exposed credentials/service-account keys; active destructive compromise; a bug that allows arbitrary cross-account access.

Initial action: disable affected capability or service path immediately, preserve minimal evidence, rotate/revoke affected credentials, and begin incident command.

### P1 — High
Examples: limited cross-user data exposure; block/unmatch bypass; protected media accessible to an unauthorized matched/unmatched user; account deletion materially failing in a way that retains sensitive data.

Initial action: contain the affected path, identify scope, and prioritize remediation before normal feature work.

### P2 — Moderate
Examples: isolated privacy inconsistency without confirmed unauthorized disclosure; abuse-rate-limit regression; non-sensitive operational metadata exposure.

Initial action: ticket, mitigate, test regression, and review whether severity should be raised as scope becomes known.

## Roles

Before external beta assign named people for:

- Incident commander: `[REQUIRED]`
- Engineering lead: `[REQUIRED]`
- Security/privacy lead: `[REQUIRED]`
- Member communications: `[REQUIRED]`
- Legal/regulatory contact: `[REQUIRED]`

One person may cover multiple roles in a small team, but ownership must be explicit.

## First-response checklist

- Record UTC start time and who declared the incident.
- Identify affected environment(s): local, staging, production.
- Freeze risky deployments unless a deployment is the containment action.
- Disable affected feature through the safest available server-side gate when possible.
- For Private Vault, keep/force the server kill switch OFF if any uncertainty affects access control or moderation.
- Revoke exposed credentials/tokens and rotate secrets when applicable.
- Do not paste message bodies, report narratives, private-media URLs, emails, or relationship-card notes into general chat/tickets.
- Preserve relevant request IDs, timestamps, affected resource IDs, commit SHAs, and sanitized logs.
- Establish an incident timeline.

## Firebase/Google Cloud containment

Depending on the incident:

- roll back or redeploy known-good Firestore/Storage rules;
- disable or gate a callable/function path;
- verify App Check enforcement state;
- inspect IAM/service-account changes;
- revoke compromised API/service credentials;
- inspect Authentication anomalies;
- confirm Storage objects are not public;
- review recent Functions/rules deployments and CI provenance.

Never “fix” an access-control incident by temporarily making rules more permissive.

## Evidence handling

Collect the minimum evidence needed. Prefer identifiers/timestamps over content. If content is necessary for an abuse/security review, restrict access and document why it was retained.

Do not download or duplicate protected media merely for convenience. Evidence involving private media requires the moderation/evidence-retention policy before routine operations.

## Member safety actions

Where relevant and supported by policy:

- block/revoke access immediately;
- terminate affected matches/conversations;
- suspend an abusive/compromised account through trusted administration;
- preserve report evidence narrowly when required;
- do not reveal reporter identity to a reported member through ordinary product flows.

## Investigation questions

- What exact trust boundary failed?
- Was the issue client-only, rules-level, callable/backend, IAM, Storage, Auth, or operational?
- Could a modified client reproduce it?
- Was App Check present and valid?
- Were block/unmatch/account-status checks revalidated at access time?
- What data classes were potentially exposed?
- How many accounts/resources were affected?
- What is the earliest and latest possible exposure time?
- Did logs themselves contain sensitive material?
- Is there evidence of exploitation, or only theoretical reachability?

## Recovery requirements

Before restoring an affected feature:

- root cause understood sufficiently to prevent recurrence;
- fix reviewed;
- negative/adversarial regression test added;
- relevant CI green;
- staging validation complete where infrastructure is involved;
- credentials rotated if exposure was possible;
- monitoring/alerting gap documented;
- member/legal notification decision documented by appropriate reviewers.

## Communications

Do not speculate publicly. Communications should distinguish confirmed facts, scope still under investigation, actions taken, and what members should do.

Before production launch define notification templates for:

- credential reset/security action;
- privacy incident notice;
- temporary feature disablement;
- resolved incident follow-up.

## Post-incident review

Within a reasonable period after stabilization, record:

- timeline;
- root cause;
- affected data/systems;
- detection gap;
- containment/recovery actions;
- tests/controls added;
- policy/process changes;
- owner and due date for every follow-up.

Avoid blame-focused writeups. The purpose is preventing recurrence and improving system safety.
