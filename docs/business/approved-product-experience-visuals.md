# Polycircle — Approved Product Experience Visuals

**Evidence label: Decision**  
**Approved:** August 18, 2026

These mockups are the approved visual direction for the next Polycircle product iteration. They are product-direction visuals, not screenshots of released functionality, and implementation must continue to respect Polycircle's security, privacy, consent, accessibility, and release gates.

## Editable visual appendix

The exact three approved mockups are preserved together in the Canva design **Polycircle Business Plan — Approved Product Experience Visuals**:

- View: https://www.canva.com/d/oYa7wegC0CpznJN
- Edit: https://www.canva.com/d/lTCVZLk__j56eRT

The visual appendix contains:

1. **Discover — Refined Experience** — Orbit Discovery, Profile Worlds, and Why Our Worlds Cross.
2. **Messages — Refined Experience** — Conversation Space, Shared Moments, and Plans.
3. **Polycircle — Approved Experience Direction** — the full cross-product journey.

## Approved Discover journey

The three Discover concepts are one progressive experience, not three competing modes:

**Orbit Discovery → Profile World → Why Our Worlds Cross → Connect / Message**

### Orbit Discovery

- Orbit is the primary Discover interaction instead of a conventional card stack.
- Members swipe/rotate through potential connections and can tap a person to focus them.
- Pass and Connect remain explicit member actions.
- The interaction must remain accessible without requiring precision gestures.

### Profile World

- Tapping a Discover person enters a richer profile experience rather than opening another discovery card.
- Existing protected profile-photo delivery, report/block controls, and Circle privacy behavior remain authoritative.
- Profile sections should progressively reveal the person's shared identity, relationship context, intentions, interests, and permitted Circle context.

### Why Our Worlds Cross

- Show only factual overlap derived from information both members intentionally shared, such as shared interests, shared intentions, or the same relationship structure.
- Do **not** present an AI-generated compatibility score, inferred psychology, or claims that Polycircle knows whether two people are a good match.
- If there is no factual overlap, do not invent one.

## Approved Messages journey

The three Messages concepts are also one progressive experience:

**Conversation Space → Save meaningful Moments → Make Plans → Shared history grows over time**

### Conversation Space

- A conversation should feel like a private space belonging to the connected members, while keeping most of the screen available for the actual chat.
- The visual relationship identity should be compact; the large orbit mockup is inspiration, not a requirement to consume half of the chat viewport.
- Existing message sending, read receipts, reporting, blocking, UGC safeguards, and connection authorization remain authoritative.

### Shared Moments

- A member should eventually be able to intentionally save meaningful messages, photos, notes, or places into the connection's shared history.
- The first implementation must be explicit/manual rather than automatic AI memory detection.
- Moments must not ship as a decorative or disconnected button. Persistence, authorization, deletion, retention, and abuse-reporting behavior must exist first.

### Plans

- Plans should originate naturally inside the conversation and appear as structured shared cards.
- The first release should support a deliberately small plan model rather than calendar/location automation.
- Plan persistence, participant authorization, editing/cancellation rules, account-deletion behavior, and retention must be defined before the UI is enabled.

## Product story

The approved interaction language is:

- **Discover:** Explore their world.
- **Profile:** Understand where your worlds intersect.
- **Messages:** Create a world together.
- **My Circle:** See how your worlds connect.

This language should guide product demos, investor storytelling, UX writing, and implementation without overstating unfinished functionality.

## Implementation discipline

The visual direction does not override engineering gates. Build the experience in testable slices, keep the app runnable after each slice, and do not add fake controls for Moments or Plans before trusted storage and lifecycle behavior exist. Private Vault remains independently gated OFF and is not part of this product-direction approval.
