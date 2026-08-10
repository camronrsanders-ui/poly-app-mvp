# Polycircle Member Data Access / Export Design

Privacy includes giving members a practical way to understand and obtain the information associated with their account. This document describes the current engineering foundation and the remaining work before a formal public data-export process is offered.

## Current trusted snapshot callable

`getMyDataSnapshot` provides an authenticated member with a bounded snapshot of their own account data through an App-Check-protected callable.

Security controls:
- authenticated user required;
- account must be active;
- recent authentication is required (within 10 minutes);
- request is rate-limited to 3 snapshots per 24 hours;
- the backend queries only data owned by or directly associated with the requesting UID;
- internal moderation collections are excluded;
- reports filed *against* the member by other people are excluded;
- protected-media Storage paths, signed URLs, reviewer identities, and moderation notes are excluded;
- every potentially large category has an explicit query bound.

## Current snapshot categories

The callable can include:
- account metadata;
- the member’s full profile, including private discovery preferences;
- relationship/Circle cards they created;
- likes they sent;
- Pass state they created;
- match history involving them;
- conversation metadata involving them;
- messages they sent;
- blocks they created;
- reports they submitted;
- profile-media metadata they own;
- Private Vault metadata they own, even though Private Vault itself remains disabled.

The snapshot intentionally does not include other members’ full profiles, email addresses, private relationship-card content, incoming reports, moderator notes, raw protected-media paths, signed media links, or other users’ message bodies merely because they share a conversation.

## Bounds and truncation

The MVP snapshot is intentionally bounded to protect the callable from unbounded memory/runtime/cost growth. It returns:

- `snapshotIsBounded: true`; and
- `truncatedCategories`, identifying any category that reached its current retrieval cap.

Current caps are engineering safety limits, not a statement that a member has no additional data. A formal statutory/consumer data-access request must not silently omit older data merely because a callable cap was reached.

## Why this is not yet the final downloadable export

The trusted snapshot creates a secure foundation, but a complete production export still needs decisions/implementation for:

1. pagination or asynchronous job processing for accounts above the callable limits;
2. identity/recent-auth verification appropriate to the jurisdiction/request type;
3. a user-friendly export format (for example structured JSON plus a human-readable index);
4. safe inclusion/exclusion of shared conversation data;
5. whether and how member-owned media files are included without exposing reusable public URLs;
6. secure temporary delivery and automatic expiration;
7. request/audit status without storing the exported sensitive payload in general logs;
8. support handling for failed/large exports;
9. response timelines and appeal/escalation requirements for launch jurisdictions;
10. consistency with account deletion, retention, backups, legal holds, and moderation evidence.

## Shared-data principle

A member data export must not become a backdoor for obtaining another member’s private data. Shared records should be minimized to what is necessary to explain the requester’s own activity/relationship to the record.

Examples:
- match/conversation IDs and participant UIDs may be necessary for the requester’s history;
- another member’s private discovery preferences are never necessary;
- incoming reports and internal moderation notes must not be disclosed through the ordinary product export;
- other participants’ message text requires a deliberate policy/legal decision rather than automatic inclusion.

## Media principle

Metadata can be exported separately from protected image bytes. If media download is added:
- authorize each object through a trusted export process;
- never make the underlying bucket/object public;
- use short-lived delivery or a temporary encrypted archive;
- remove temporary export artifacts on expiry;
- do not include rejected/reported evidence without an approved policy basis.

## Release gate

Before external beta/public release, decide whether the initial product offers:

- self-service complete export;
- support-mediated access requests; or
- both.

Whichever path is chosen must be documented in the public Privacy Policy, tested end-to-end, and capable of servicing accounts whose data exceeds the bounded in-app snapshot limits.
