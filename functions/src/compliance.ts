import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {
  CURRENT_COMMUNITY_GUIDELINES_VERSION,
  CURRENT_TERMS_VERSION,
} from './account_compliance';

const allowedMethods = new Set([
  'apple_declared_age_range',
  'play_age_signals',
  'self_attested_dob_fallback',
]);

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

function requireMethod(raw: unknown): string {
  const method = String(raw ?? '').trim();
  if (!allowedMethods.has(method)) {
    throw new HttpsError('invalid-argument', 'Unsupported age assurance method.');
  }
  return method;
}

function requireSignalStatus(raw: unknown): string {
  const status = String(raw ?? '').trim();
  if (!status || status.length > 80 || !/^[A-Za-z0-9:_-]+$/.test(status)) {
    throw new HttpsError('invalid-argument', 'Invalid age assurance status.');
  }
  return status;
}

export const recordAdultPolicyAcceptance = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);
    const method = requireMethod(request.data?.ageAssuranceMethod);
    const signalStatus = requireSignalStatus(request.data?.ageSignalStatus);

    // A platform-backed approval must arrive from the native bridge as an adult
    // decision. Self-attestation is intentionally labeled separately and is not
    // misrepresented as verified age. This callable removes the trivial direct
    // Firestore bypass; store/platform controls remain necessary because a
    // self-attested fallback is inherently based on the member's declaration.
    if (method !== 'self_attested_dob_fallback'
        && !signalStatus.startsWith('adult:')) {
      throw new HttpsError('failed-precondition', 'The platform did not confirm adult access.');
    }
    if (signalStatus.startsWith('minor:')
        || signalStatus.startsWith('verificationRequired:')) {
      throw new HttpsError('permission-denied', 'Adult access is not available for this account.');
    }

    const userRef = db.collection('users').doc(uid);
    await db.runTransaction(async (tx) => {
      const user = await tx.get(userRef);
      if (!user.exists || user.get('accountStatus') !== 'active') {
        throw new HttpsError('permission-denied', 'Account is not active.');
      }

      tx.set(userRef, {
        adultAccessApproved: true,
        termsAcceptedVersion: CURRENT_TERMS_VERSION,
        communityGuidelinesAcceptedVersion: CURRENT_COMMUNITY_GUIDELINES_VERSION,
        ageAssuranceMethod: method,
        ageSignalStatus: signalStatus,
        ageAssuranceCheckedAt: FieldValue.serverTimestamp(),
        ugcPolicyAcceptedAt: FieldValue.serverTimestamp(),
        lastActiveAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });

    return {
      approved: true,
      termsVersion: CURRENT_TERMS_VERSION,
      communityGuidelinesVersion: CURRENT_COMMUNITY_GUIDELINES_VERSION,
    };
  },
);
