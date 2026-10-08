# Polycircle Product Specification

Polycircle is a mobile-first dating, friendship, relationship, and community app for polyamorous, ENM, open-relationship, relationship-anarchy, and relationship-exploring adults.

Tagline: Connect openly. Love honestly. Build your circle.

## Core concepts
- Relationship structure is first-class profile data.
- Users can seek friendship, community, dating, long-term relationships, casual connection, joining or building a polycule, and exploration/learning.
- Inclusive gender identity, pronoun, and orientation fields with custom options.
- Relationship Cards are the MVP foundation for future visual polycule mapping.
- Connections are not assumed to be romantic.

## Main navigation
Discover, Connections, Circle, Messages, Profile.

## MVP build order
Authentication; onboarding; profiles; relationship cards; discover and filters; likes and mutual connections; conversations and messages; blocking and reporting; privacy/security; end-to-end testing.

## Onboarding
Use a multi-step flow: Welcome; Basics; Identity; Pronouns; Orientation; Relationship Structure; Relationship Status; Intentions; Preferences; Profile; Photos; Build Your Circle; Privacy; Finish.

Relationship structure examples: solo poly, hierarchical poly, non-hierarchical poly, open relationship, polyfidelity, relationship anarchy, monogamish, exploring, custom.

Intentions allow multiple selections: friendship, community, dating, long-term relationship, casual connection, join a polycule, build/grow a polycule, exploring/learning.

## Relationship cards
Users can create, view, edit, reorder, deactivate, and delete cards. Privacy options: public, matches_only, private, unnamed_public. Do not expose another person's identity without appropriate consent. Future phase: interactive visual polycule graph.

## Discover
Show profile information that helps users understand identity, relationship structure, intentions, and compatibility. Actions: Pass, Like/Connect, View Profile. Filtering: age, distance, relationship structure, intentions, identity preferences, open-to-connections. Exclude self, blocked users, hidden profiles, and inactive/suspended accounts.

## Matching
Prevent duplicate likes and self-likes. A mutual like creates one canonical connection. Avoid duplicate A+B and B+A match records.

## Messaging
Only connected users can start a conversation. MVP supports text messaging, chronological loading, read state, last-message timestamp, loading/empty/error states, and block/report access.

## Safety
Blocking must stop discovery and messaging access as appropriate. Reporting must support clear reasons, details, timestamps, and moderation status.

## Security
Do not ship unrestricted Firestore rules. Enforce ownership and membership checks for profiles, relationship cards, likes, matches, conversations, messages, reports, and blocks.

## Definition of done
A feature is complete only when UI, navigation, backend, persistence, permissions, loading, empty, error states, and basic testing work. MVP journey: signup -> onboarding -> profile -> relationship card -> discover -> like -> mutual connection -> conversation -> messages -> block/report -> logout/login with data retained.