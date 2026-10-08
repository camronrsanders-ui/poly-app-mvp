# Polycircle Onboarding Flow

## Goal
Collect enough information for safe, meaningful discovery without overwhelming the user. Use a multi-step mobile flow with progress indication and the ability to go back.

## Step 1 — Welcome
Message: Polycircle is built for poly, ENM, friendship, dating, and community.
CTA: Get Started

## Step 2 — Basics
Fields:
- displayName
- age or date of birth
- city
- region

Validation:
- adult-only app; enforce 18+
- display name required

## Step 3 — Identity
Question: How do you identify?
Support multiple/custom values where useful.
Examples:
- man
- woman
- nonbinary
- genderfluid
- agender
- trans man
- trans woman
- self-described/custom

## Step 4 — Pronouns
Examples:
- he/him
- she/her
- they/them
- multiple pronoun sets
- custom/self-described

## Step 5 — Orientation
Support flexible sexual/romantic orientation choices and custom values.

## Step 6 — Relationship Structure
Question: Which relationship structure best describes you right now?
Options:
- solo_poly
- hierarchical_poly
- non_hierarchical_poly
- open_relationship
- polyfidelity
- relationship_anarchy
- monogamish
- exploring
- custom

Provide short optional explanations.

## Step 7 — Relationship Status
Options:
- single
- partnered
- multiple_partners
- part_of_polycule
- complicated_or_custom
- prefer_not_to_say

Also collect:
- partnered: boolean
- openToConnections: boolean

## Step 8 — Intentions
Question: What are you hoping to find on Polycircle?
Multi-select:
- friendship
- community
- dating
- long_term_relationship
- casual_connection
- join_a_polycule
- build_or_grow_a_polycule
- exploring_or_learning

## Step 9 — Discovery Preferences
Fields:
- ageMin
- ageMax
- distanceRadius
- preferredStructures (optional multi-select)
- preferredIntentions (optional multi-select)

Do not force preference filters the user does not care about.

## Step 10 — Profile
Fields:
- headline
- bio
- interests
- lookingForNote

Suggested prompts:
- What does healthy connection look like to you?
- What kind of energy are you hoping to meet here?
- What should people know about your relationship style?

## Step 11 — Photos
Support avatar/profile photo and additional photo URLs when storage is configured.
Do not fake successful upload behavior if storage is unavailable.

## Step 12 — Build Your Circle
Explain relationship cards as an optional way to represent current important connections.
Actions:
- Add relationship card
- Skip for now

A user must be able to finish onboarding without adding a relationship card.

## Step 13 — Privacy
Set:
- profileVisibility
- mapVisibility

Explain each option in plain language.

## Step 14 — Review & Finish
Show a concise summary.
On submit:
1. validate required fields
2. create/update profiles/{uid}
3. set users/{uid}.onboardingComplete = true
4. update timestamps
5. route to Discover/main navigation

## Resume Behavior
If onboarding is interrupted, preserve draft progress where practical and return the authenticated user to the correct incomplete step.