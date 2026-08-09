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

export function candidateMatchesPreferences(
  requester: ProfileData,
  candidate: ProfileData,
): boolean {
  const candidateAge = Number(candidate.age);
  if (!Number.isInteger(candidateAge) || candidateAge < 18 || candidateAge > 120) {
    return false;
  }

  const minAge = boundedAge(requester.ageMin, 18);
  const maxAge = Math.max(minAge, boundedAge(requester.ageMax, 120));
  if (candidateAge < minAge || candidateAge > maxAge) return false;

  const preferredStructures = stringList(requester.preferredStructures);
  if (preferredStructures.length > 0) {
    const structure = typeof candidate.relationshipStructure === 'string'
      ? candidate.relationshipStructure
      : '';
    if (!preferredStructures.includes(structure)) return false;
  }

  const preferredIntentions = stringList(requester.preferredIntentions);
  if (preferredIntentions.length > 0) {
    const candidateIntentions = new Set(stringList(candidate.intentionTags));
    if (!preferredIntentions.some((intention) => candidateIntentions.has(intention))) {
      return false;
    }
  }

  return true;
}
