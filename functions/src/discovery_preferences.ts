type ProfileData = FirebaseFirestore.DocumentData;

function stringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === 'string');
}

function boundedAge(value: unknown, fallback: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(120, Math.max(18, Math.trunc(parsed)));
}

function validAdultAge(value: unknown): number | null {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 18 || parsed > 120) return null;
  return parsed;
}

function viewerAcceptsProfile(viewer: ProfileData, profile: ProfileData): boolean {
  const profileAge = validAdultAge(profile.age);
  if (profileAge == null) return false;

  const minAge = boundedAge(viewer.ageMin, 18);
  const maxAge = Math.max(minAge, boundedAge(viewer.ageMax, 120));
  if (profileAge < minAge || profileAge > maxAge) return false;

  const preferredStructures = stringList(viewer.preferredStructures);
  if (preferredStructures.length > 0) {
    const structure = typeof profile.relationshipStructure === 'string'
      ? profile.relationshipStructure
      : '';
    if (!preferredStructures.includes(structure)) return false;
  }

  const preferredIntentions = stringList(viewer.preferredIntentions);
  if (preferredIntentions.length > 0) {
    const profileIntentions = new Set(stringList(profile.intentionTags));
    if (!preferredIntentions.some((intention) => profileIntentions.has(intention))) {
      return false;
    }
  }

  return true;
}

export function candidateMatchesPreferences(
  requester: ProfileData,
  candidate: ProfileData,
): boolean {
  // Discovery is reciprocal: do not show a candidate unless each person's
  // saved age/structure/intention preferences permit the other. This keeps
  // preference data private while respecting both users' boundaries.
  return viewerAcceptsProfile(requester, candidate)
    && viewerAcceptsProfile(candidate, requester);
}
