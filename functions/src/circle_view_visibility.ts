// Profile-visibility cap for the Circle profile read (H-11).
//
// The callable in circle_view.ts owns all Firestore access; this module owns
// the pure decision that must stay testable without a database: whether a
// non-owner may read an owner's Circle at all under the owner's
// profileVisibility, before the mapVisibility gate and per-card filtering
// apply. The semantics mirror canViewOwnerProfile (profile_access.ts), the
// canonical gate the profile view and profile media already follow:
// 'public' allows, 'matches_only' requires an active match, and 'hidden',
// a missing field, or any unrecognized value fails closed. Co-membership
// in one of the owner's Circles confers nothing here: only a match counts.

// Returns the denial message for a non-owner read, or null when the
// profile-visibility cap allows the read to continue to the map gate.
// The messages deliberately match the existing denial family: the generic
// 'Circle is unavailable.' never reveals which setting caused the denial.
export function circleProfileVisibilityDenial(
  profileVisibility: unknown,
  matched: boolean,
): string | null {
  const visibility = String(profileVisibility ?? 'hidden');
  if (visibility === 'public') return null;
  if (visibility === 'matches_only') {
    return matched ? null : 'Circle is available to connections only.';
  }
  return 'Circle is unavailable.';
}
