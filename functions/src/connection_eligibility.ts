import {HttpsError} from 'firebase-functions/v2/https';

export async function assertCanReceiveNewConnection(
  db: FirebaseFirestore.Firestore,
  targetUid: string,
): Promise<void> {
  const profile = await db.collection('profiles').doc(targetUid).get();
  if (!profile.exists) {
    throw new HttpsError('not-found', 'Profile is unavailable.');
  }

  // New interest can only be sent to someone who has explicitly chosen to be
  // discoverable and open to new connections. Existing matches use their own
  // trusted lifecycle and are unaffected by this discovery preference.
  if (profile.get('profileVisibility') !== 'public' || profile.get('openToConnections') !== true) {
    throw new HttpsError('permission-denied', 'This profile is not accepting new connections.');
  }
}
