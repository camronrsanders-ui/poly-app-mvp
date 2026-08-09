const publicProfileFields = [
  'displayName',
  'age',
  'city',
  'region',
  'bio',
  'headline',
  'genderIdentity',
  'pronouns',
  'orientation',
  'customIdentityTags',
  'relationshipStructure',
  'relationshipStatus',
  'partnered',
  'intentionTags',
  'interests',
  'lookingForNote',
] as const;

export function toProfileView(
  uid: string,
  data: FirebaseFirestore.DocumentData,
): FirebaseFirestore.DocumentData {
  const output: FirebaseFirestore.DocumentData = {uid};
  for (const key of publicProfileFields) {
    if (data[key] !== undefined) output[key] = data[key];
  }
  return output;
}
