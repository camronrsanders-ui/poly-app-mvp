import {HttpsError} from 'firebase-functions/v2/https';

export const CURRENT_TERMS_VERSION = '2026-08-alpha-v1';
export const CURRENT_COMMUNITY_GUIDELINES_VERSION = '2026-08-v1';

export function isActiveAccount(
  user: FirebaseFirestore.DocumentSnapshot,
): boolean {
  return user.exists && user.get('accountStatus') === 'active';
}

export async function assertActiveAccount(
  db: FirebaseFirestore.Firestore,
  uid: string,
): Promise<FirebaseFirestore.DocumentSnapshot> {
  const user = await db.collection('users').doc(uid).get();
  if (!isActiveAccount(user)) {
    throw new HttpsError('permission-denied', 'This Polycircle account is unavailable.');
  }
  return user;
}

/**
 * Member eligibility is fail-closed. Legacy records without explicit adult
 * approval and current policy acceptance cannot access member features.
 * Self account access for compliance/recovery is handled separately.
 */
export function isActiveCompliantMember(
  user: FirebaseFirestore.DocumentSnapshot,
): boolean {
  if (!isActiveAccount(user)) return false;

  const data = user.data() ?? {};
  return data.adultAccessApproved === true
    && data.termsAcceptedVersion === CURRENT_TERMS_VERSION
    && data.communityGuidelinesAcceptedVersion === CURRENT_COMMUNITY_GUIDELINES_VERSION;
}

export async function assertActiveCompliantMember(
  db: FirebaseFirestore.Firestore,
  uid: string,
): Promise<FirebaseFirestore.DocumentSnapshot> {
  const user = await db.collection('users').doc(uid).get();
  if (!isActiveCompliantMember(user)) {
    throw new HttpsError(
      'permission-denied',
      'Complete adult access and the current community policies before using this feature.',
    );
  }
  return user;
}
