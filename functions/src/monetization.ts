import {getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {assertActiveCompliantMember} from './account_compliance';
import {resolvePublicEntitlement} from './monetization_entitlements';

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

/**
 * Read-only entitlement endpoint used by the client to render paid/free UI.
 *
 * The backing collection is intentionally backend-only. Future StoreKit / Play
 * Billing verification code may write `_billing_entitlements`, but clients must
 * never be allowed to write that collection directly or submit a tier/status
 * value that is trusted as proof of purchase.
 */
export const getMyEntitlements = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);
    await assertActiveCompliantMember(db, uid);

    const snapshot = await db.collection('_billing_entitlements').doc(uid).get();
    return resolvePublicEntitlement(snapshot.data());
  },
);
