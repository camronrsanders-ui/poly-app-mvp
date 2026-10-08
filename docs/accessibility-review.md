# Polycircle Accessibility Review

This is a pre-release engineering checklist. Automated tests can catch regressions, but real assistive-technology and device testing remains required.

## Current design expectations

- Use Material controls with semantic roles instead of custom gesture-only controls where possible.
- Every icon-only action needs a tooltip/accessible label.
- Do not communicate relationship/safety state through color alone.
- Support Dynamic Type / larger text without clipping critical actions.
- Keep tap targets comfortably usable on phones.
- Maintain logical keyboard/focus order where desktop/web support is introduced.
- Error messages must identify the problem in text and not only by field color.
- Loading states must not trap the user indefinitely without a recovery path.
- Safety/report/block actions must remain reachable with assistive technologies.

## Screen checklist

### Authentication
- Login/signup fields have visible labels/hints.
- Password controls have understandable semantics.
- Validation/error text is readable by screen readers.
- Keyboard does not hide the primary action.

### Onboarding
- All multi-select chips expose selected state.
- Age inputs/sliders have meaningful values.
- Long content remains scrollable at large text sizes.
- Required vs optional questions are stated in text.
- Recovery after save failure does not erase answers.

### Discover
- Profile order is navigable linearly.
- Pass, View profile, and Connect have distinct accessible labels.
- A profile does not rely on images alone to convey identity/context.
- Empty/error/loading states are understandable without visual icons.

### Profile detail
- Photo carousel can be navigated without requiring precise swipes only.
- Image failure has a non-image fallback.
- Report/block actions are reachable and clearly named.
- Relationship-card privacy explanation is readable at large text sizes.

### Connections / Messages
- Connection menu actions have labels.
- Message bubbles expose sender context when needed by screen readers.
- Message composer and Send button are reachable in sensible order.
- Failed sends preserve the draft and expose the failure as text.

### Circle
- Move up/down controls have tooltips.
- Relationship privacy values are understandable when read aloud.
- Editor controls use labeled fields.
- Reorder should eventually support a less repetitive accessibility path if many cards are present.

### Safety Center
- Manage blocked members is reachable without profile navigation.
- Unblock confirmation explains that old connections do not return automatically.
- Safety content is not conveyed through icons alone.

### Profile/account settings
- Destructive account deletion requires clear textual confirmation.
- Pending deletion recovery is screen-reader accessible.
- Profile photo status should use text labels, not only visual state.

## Manual test matrix before external beta

### iOS
- VoiceOver on a real iPhone.
- Dynamic Type at largest accessibility sizes.
- Increase Contrast.
- Reduce Motion.
- Bold Text.
- Display Zoom where supported.

### Android
- TalkBack on a real Android device.
- Font size/display size at large settings.
- High contrast / color-correction checks where available.

## Visual checks

- Text/background contrast meets the intended accessibility target.
- Focus/selected states remain distinguishable.
- Chips/buttons remain readable with long relationship labels.
- Dark-mode support is not claimed until a dark theme is intentionally designed/tested.

## Motion

Avoid non-essential animation that cannot respect reduced-motion preferences. Current MVP should prefer platform-default transitions and progress indicators over elaborate motion.

## Media

Profile photos are member-generated and cannot reliably have meaningful author-provided alt text in the current design. Do not invent descriptive personal attributes from images. Profile-photo carousel pages now expose deliberate position semantics such as “Profile photo 1 of 3”; these semantics still require real VoiceOver/TalkBack acceptance testing.

## Known release work

- Add targeted widget tests for semantics on core controls.
- Run real VoiceOver/TalkBack acceptance journeys.
- Verify large-text layouts on every core screen.
- Validate profile-photo carousel position semantics during real VoiceOver/TalkBack acceptance.
- Perform a contrast review against the final branded theme.
- Review any future web/desktop focus/keyboard behavior separately.

External/public beta remains blocked until the manual accessibility review is completed and material blockers are addressed or explicitly documented.
