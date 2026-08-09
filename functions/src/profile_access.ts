import {HttpsError} from 'firebase-functions/v2/https';

async function assertActive(
  db: FirebaseFirestore.Firestore,
  uid: string,
): Promise<void> {
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

async function isBlocked(
  db: FirebaseFirestore.Firestore,
  a: string,
  b: string,
): Promise<boolean> {
  const [ab, ba] = await Promise.all([
    db.collection('blocks').doc(`${a}_${b}`).get(),
    db.collection('blocks').doc(`${b}_${a}`).get(),
  ]);
  return ab.exists || ba.exists;
}

async function hasActiveMatch(
  db: FirebaseFirestore.Firestore,
  a: string,
  b: string,
): Promise<boolean> {
  const match = await db.collection('matches').doc([a, b].sort().join('_')).get();
  return match.exists && match.get('active') === true;
}

export async function canViewOwnerProfile(
  db: FirebaseFirestore.Firestore,
  requesterUid: string,
  ownerUid: string,
): Promise<boolean> {
  if (requesterUid === ownerUid) {
    await assertActive(db, requesterUid);
    return true;
  }

  await Promise.all([
    assertActive(db, requesterUid),
    assertActive(db, ownerUid),
  ]);
  if (await isBlocked(db, requesterUid, ownerUid)) return false;

  const profile = await db.collection('profiles').doc(ownerUid).get();
  if (!profile.exists) return false;
  const visibility = String(profile.get('profileVisibility') ?? 'hidden');
  if (visibility === 'public') return true;
  return visibility === 'matches_only'
    && await hasActiveMatch(db, requesterUid, ownerUid);
}
