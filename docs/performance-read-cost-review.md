# Polycircle Performance & Firebase Read-Cost Review

This document records current MVP bounds and the checks required before scale testing. It is not a production cost forecast.

## Principles

- Security/privacy boundaries take priority over shaving a read.
- Avoid client collection scans when trusted backend aggregation is required anyway.
- Bound every list/candidate query.
- Avoid N+1 sequential reads in request paths.
- Do not expose private fields merely to reduce backend work.
- Measure staging behavior before selecting production quotas/budgets.

## Discover

Current trusted Discover behavior:

- client asks for a bounded candidate count;
- backend clamps the requested output to 1–40 and safely defaults malformed limits;
- backend scans a bounded public/open candidate pool with a maximum of 120 profiles;
- user state, pass state, outgoing likes, prior matches, bilateral block documents, and private candidate-location documents are fetched in batches;
- reciprocal private preferences are applied in trusted code;
- the requester's saved 5/10/20/30/50/100-mile radius is applied in trusted code and eligible candidates are ordered nearest-first;
- output uses a sanitized display-safe profile view.

This removes the previous per-candidate sequential block lookup from the hot loop and does not expose coordinates to reduce read cost. Remaining scale concern: bounded scanning can under-fill results when many candidates fail reciprocal or distance filters. Before production scale, design and stage-test a private geospatial index/bounded-query strategy (for example server-owned geohash ranges plus exact trusted distance verification). Do not move coordinate filtering to the client as a shortcut. Pagination/ranking and measured read/latency behavior remain part of that decision.

## Connections / Messages list

Current trusted connection listing:

- queries the two participant-key match paths separately;
- filters active state in trusted code to avoid a composite-index dependency for the basic list;
- caps returned active unique connections at 100;
- batches account, profile, conversation, and bilateral block reads with `getAll`;
- returns only sanitized profile fields plus trusted conversation metadata;
- sorts by last-message timestamp in trusted code.

The Messages tab reuses this trusted connection view rather than attempting an unsafe Firestore conversation collection query.

## Live chat

The client queries up to the last 100 messages for one known conversation, ordered by creation time. Firestore rules revalidate active conversation membership/block state for reads/writes.

Potential future work:

- paginate older messages rather than increasing the live limit;
- measure read-replay behavior on reconnect;
- add delivery/read-state cost telemetry without logging message content;
- consider trusted server message send only if abuse controls or notification fan-out require it.

## Circle

Owner Circle uses a direct owner-scoped query ordered by sortOrder. Trusted cross-user Circle views remain backend-controlled/redacted. Keep the number of active relationship cards reasonably bounded in product/rules if real-world usage shows abuse/cost risk.

## Profile photos

Remote profile photo listing is limited to 20 metadata documents and returns only active images through short-lived signed URLs. Image bytes come from Storage rather than Firestore.

Before beta measure:

- signed-URL generation latency;
- image-processing memory/time;
- 2048px processed-image bandwidth;
- cache behavior under short-lived URLs;
- moderation queue/storage growth.

## Private Vault

Private Vault remains disabled. Its request/grant/listing functions are bounded, but no production cost assumptions should be made until the feature’s policy/moderation architecture is complete.

## Rate-limit documents

Trusted callables use user/action-scoped rate-limit documents. This adds Firestore transaction reads/writes intentionally as an abuse-control cost. Before scale, evaluate whether high-volume actions need a dedicated rate-limit system without weakening protection.

## Startup behavior

Main navigation tabs are lazy-loaded. Only Discover is created at initial shell startup; Connections, Circle, Messages, and Profile initialize on first selection. This avoids starting all network-backed screens simultaneously and reduces noisy unrelated failures during app startup.

## Pre-beta measurement plan

On staging, record for representative actions:

- p50/p95 callable latency;
- Firestore document reads/writes per action;
- Functions invocation count/duration/memory;
- Storage operations and egress for media;
- cold-start impact;
- error/retry rate;
- App Check rejection rate;
- client reconnect behavior.

Test at least:

- empty/new account;
- typical account (20 Discover candidates, several Circle cards, 10 connections);
- connection-heavy account near the 100-result cap;
- chat with 100+ messages;
- accounts with many passes/blocks;
- media-heavy profile within allowed limits.

## Budget controls before production

Once a paid project exists:

- configure billing budgets/alerts appropriate to the environment;
- set/confirm Functions maxInstances and quotas;
- keep staging/prod separate where practical;
- review anomalous read/invocation patterns;
- never use budget pressure as justification to weaken authorization checks.

## Current conclusion

The MVP now has explicit bounds on its primary list/read paths and removes known sequential N+1 behavior in Discover/Connections. Large-scale ranking/pagination and real Firebase cost/latency measurements remain staging/production-readiness work.
