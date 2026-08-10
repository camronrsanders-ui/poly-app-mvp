type ProfileData = FirebaseFirestore.DocumentData;

function safeString(value: unknown, maxLength: number): string | undefined {
  if (typeof value !== 'string') return undefined;
  return value.slice(0, maxLength);
}

function safeStringList(
  value: unknown,
  maxItems: number,
  maxItemLength: number,
): string[] | undefined {
  if (!Array.isArray(value)) return undefined;
  const seen = new Set<string>();
  const output: string[] = [];
  for (const item of value) {
    if (typeof item !== 'string') continue;
    const normalized = item.trim().slice(0, maxItemLength);
    if (!normalized || seen.has(normalized)) continue;
    seen.add(normalized);
    output.push(normalized);
    if (output.length >= maxItems) break;
  }
  return output;
}

function safeAdultAge(value: unknown): number | undefined {
  const age = Number(value);
  if (!Number.isInteger(age) || age < 18 || age > 120) return undefined;
  return age;
}

export function toProfileView(uid: string, data: ProfileData): ProfileData {
  // Treat Firestore documents as untrusted input at the cross-user boundary.
  // Security rules protect ordinary client writes, but legacy/admin/test data
  // must never be able to crash another member's UI or smuggle nested values.
  const output: ProfileData = {uid};

  const strings: Array<[string, number]> = [
    ['displayName', 80],
    ['city', 100],
    ['region', 100],
    ['bio', 1500],
    ['headline', 160],
    ['genderIdentity', 100],
    ['pronouns', 100],
    ['orientation', 100],
    ['relationshipStructure', 120],
    ['relationshipStatus', 120],
    ['lookingForNote', 1200],
  ];
  for (const [key, maxLength] of strings) {
    const value = safeString(data[key], maxLength);
    if (value !== undefined) output[key] = value;
  }

  const age = safeAdultAge(data.age);
  if (age !== undefined) output.age = age;
  if (typeof data.partnered === 'boolean') output.partnered = data.partnered;

  const customIdentityTags = safeStringList(data.customIdentityTags, 12, 100);
  if (customIdentityTags !== undefined) output.customIdentityTags = customIdentityTags;
  const intentionTags = safeStringList(data.intentionTags, 12, 100);
  if (intentionTags !== undefined) output.intentionTags = intentionTags;
  const interests = safeStringList(data.interests, 20, 100);
  if (interests !== undefined) output.interests = interests;

  return output;
}
