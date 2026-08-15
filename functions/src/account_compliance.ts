import {HttpsError} from 'firebase-functions/v2/https';

export const CURRENT_TERMS_VERSION = '2026-08-alpha-v1';
export const CURRENT_COMMUNITY_GUIDELINES_VERSION = '2026-08-v1';

/**
 * Temporary migration-aware member eligibility check.
 *
 * New Polycircle accounts always include adultAccessApproved, so any account
 * with that field must have completed the current adult + policy gate. Older
 * local/test accounts may temporarily omit the field while fixtures are
 * migrated; that compatibility branch must be removed before public release.
 */
export function isActiveCompliantMember(
  user: FirebaseFirestore.DocumentSnapshot,
): boolean {
  if (!user.exists || user.get('accountStatus') !== 'active') return false;

  const data = user.data() ?? {};
  if (!Object.prototype.hasOwnProperty.call(data, 'adultAccessApproved')) {
    return true;
  }

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
