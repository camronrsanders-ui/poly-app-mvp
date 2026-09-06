import {HttpsError} from 'firebase-functions/v2/https';

export function assertCanReceiveNewConnection(
  profile: FirebaseFirestore.DocumentSnapshot,
): void {
  if (!profile.exists) {
    throw new HttpsError('not-found', 'Profile is unavailable.');
  }

  // Callers supply the profile snapshot they read inside the same Firestore
  // transaction that creates interest/match state. This prevents a target from
  // hiding their profile or closing new connections in the authorization-to-
  // write gap.
  if (profile.get('profileVisibility') !== 'public' || profile.get('openToConnections') !== true) {
    throw new HttpsError('permission-denied', 'This profile is not accepting new connections.');
  }
}
