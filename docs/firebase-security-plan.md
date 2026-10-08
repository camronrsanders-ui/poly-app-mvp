# Polycircle — Firebase Security & Privacy Plan

## Purpose
This document defines the minimum security behavior for the MVP. The final `firestore.rules` must be tested against the implemented queries and data model before release.

## General Rules
- Require authentication for non-public app data.
- Never rely on UI hiding as authorization.
- Ownership fields must be validated against `request.auth.uid`.
- Users must not be able to grant themselves moderator/admin privileges.
- Do not commit service-account credentials or private API secrets.

## users/{uid}
- Owner can read their own document.
- Owner can update allowed self-service fields.
- User must not be able to set protected administrative state such as `banned`/`suspended` if moderation later controls those values.
- Creation should require `uid == request.auth.uid`.

## profiles/{uid}
- Owner can create/update their profile.
- Public/authorized reads must respect `profileVisibility` and blocks.
- Ownership field `uid` should remain equal to document ID/auth owner.

## relationship_cards/{cardId}
- Create requires `ownerUid == request.auth.uid`.
- Update/delete requires existing `ownerUid == request.auth.uid`.
- Reads must respect card visibility and broader map/profile privacy.

## likes/{likeId}
- Create requires `fromUid == request.auth.uid`.
- Disallow self-like.
- Prevent user from editing a like so it appears to come from another UID.
- Consider trusted/canonical logic for duplicate prevention if client-only rules are insufficient.

## matches/{matchId}
- Reads require authenticated user to be one of the match participants.
- Match creation should preferably use trusted logic/canonical pair IDs when possible.
- Ordinary clients should not be able to forge arbitrary matches.

## conversations/{conversationId}
- Read requires membership in `participantUids`.
- Create should require the requester to be a participant and the pair to be legitimately connected/matched.
- Updates should not allow arbitrary participant replacement.

## messages/{messageId}
- Read requires membership in referenced conversation.
- Create requires `senderUid == request.auth.uid` and conversation membership.
- Users should not be able to rewrite another user's sender identity.

## blocks/{blockId}
- Create requires `blockerUid == request.auth.uid`.
- Owner may manage their own block records.
- App queries and trusted logic must enforce block consequences across discovery, profiles, matching, and messaging.

## reports/{reportId}
- Create requires `reporterUid == request.auth.uid`.
- Reported user should not automatically gain read access to report details.
- Reporter should not be able to change moderation-only status values after submission if status is admin-controlled.

## Storage
When Firebase Storage is enabled for profile media:
- Require authenticated upload.
- Restrict users to their own media paths.
- Validate content type and reasonable file size.
- Do not expose private media solely through predictable file naming.

## Privacy Precedence
More restrictive settings win.
Example: if mapVisibility is `public` but a relationship card is `private`, the card remains private.

## Production Checklist
Before beta/release:
- Firestore is not in open test mode.
- Emulator/rules tests cover cross-user write attempts.
- Unauthorized conversation/message reads fail.
- Cross-user profile/card edits fail.
- Block behavior is verified in queries and UI.
- No secrets exist in repository history/current files.
- Required Firestore indexes are deployed.
