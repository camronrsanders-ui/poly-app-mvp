import {getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

const db = getFirestore();

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

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

async function assertActive(uid: string): Promise<void> {
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

async function isBlocked(a: string, b: string): Promise<boolean> {
  const [ab, ba] = await Promise.all([
    db.collection('blocks').doc(`${a}_${b}`).get(),
    db.collection('blocks').doc(`${b}_${a}`).get(),
  ]);
  return ab.exists || ba.exists;
}

export const listMyConnections = onCall(
  {enforceAppCheck: true, maxInstances: 25},
  async (request) => {
    const uid = requireUid(request.auth);
    await assertActive(uid);

    const [asA, asB] = await Promise.all([
      db.collection('matches')
        .where('userAUid', '==', uid)
        .where('active', '==', true)
        .limit(100)
        .get(),
      db.collection('matches')
        .where('userBUid', '==', uid)
        .where('active', '==', true)
        .limit(100)
        .get(),
    ]);

    const matches = [...asA.docs, ...asB.docs];
    const seen = new Set<string>();
    const output: FirebaseFirestore.DocumentData[] = [];

    for (const match of matches) {
      const data = match.data();
      const otherUid = data.userAUid === uid
        ? String(data.userBUid ?? '')
        : String(data.userAUid ?? '');
      if (!otherUid || seen.has(otherUid)) continue;
      seen.add(otherUid);

      if (await isBlocked(uid, otherUid)) continue;
      const [user, profile] = await Promise.all([
        db.collection('users').doc(otherUid).get(),
        db.collection('profiles').doc(otherUid).get(),
      ]);
      if (!user.exists || user.get('accountStatus') !== 'active' || !profile.exists) continue;

      output.push({
        ...toProfileView(otherUid, profile.data()!),
        matchId: match.id,
      });
    }

    return {connections: output};
  },
);
