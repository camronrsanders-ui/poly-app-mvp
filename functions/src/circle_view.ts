import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {assertActiveCompliantMember} from './account_compliance';

const db = getFirestore();

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

function requireOwnerUid(raw: unknown): string {
  const uid = String(raw ?? '').trim();
  if (!uid || uid.length > 128 || !/^[A-Za-z0-9:_-]+$/.test(uid)) {
    throw new HttpsError('invalid-argument', 'Invalid profile owner.');
  }
  return uid;
}

async function assertActive(uid: string): Promise<void> {
  await assertActiveCompliantMember(db, uid);
}

async function consumeRateLimit(uid: string): Promise<void> {
  const action = 'circle_view';
  const ref = db.collection('_rate_limits').doc(`${action}_${uid}`);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const start = Number(snap.get('windowStartMs') ?? 0);
    const count = Number(snap.get('count') ?? 0);
    if (!snap.exists || now - start >= 60_000) {
      tx.set(ref, {
        uid,
        action,
        windowStartMs: now,
        count: 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }
    if (count >= 60) {
      throw new HttpsError('resource-exhausted', 'Too many Circle requests. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

function pairId(a: string, b: string): string {
  return [a, b].sort().join('_');
}

async function isBlocked(a: string, b: string): Promise<boolean> {
  const [ab, ba] = await Promise.all([
    db.collection('blocks').doc(`${a}_${b}`).get(),
    db.collection('blocks').doc(`${b}_${a}`).get(),
  ]);
  return ab.exists || ba.exists;
}

async function hasActiveMatch(a: string, b: string): Promise<boolean> {
  const match = await db.collection('matches').doc(pairId(a, b)).get();
  return match.exists && match.get('active') === true;
}

function safeCard(
  card: FirebaseFirestore.QueryDocumentSnapshot,
  redactIdentity: boolean,
): FirebaseFirestore.DocumentData {
  const data = card.data();
  return {
    cardId: card.id,
    label: String(data.label ?? '').slice(0, 100),
    connectionType: String(data.connectionType ?? '').slice(0, 100),
    status: String(data.status ?? '').slice(0, 80),
    visibility: String(data.visibility ?? 'private'),
    sortOrder: Number(data.sortOrder ?? 0),
    ...(!redactIdentity && typeof data.displayNameOptional === 'string'
      ? {displayNameOptional: data.displayNameOptional.slice(0, 100)}
      : {}),
    ...(!redactIdentity && typeof data.note === 'string'
      ? {note: data.note.slice(0, 1000)}
      : {}),
  };
}

export const getCircleForProfile = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const requesterUid = requireUid(request.auth);
    const ownerUid = requireOwnerUid(request.data?.ownerUid);
    await Promise.all([assertActive(requesterUid), consumeRateLimit(requesterUid)]);
    await assertActive(ownerUid);

    if (requesterUid !== ownerUid && await isBlocked(requesterUid, ownerUid)) {
      throw new HttpsError('permission-denied', 'Circle is unavailable.');
    }

    const profile = await db.collection('profiles').doc(ownerUid).get();
    if (!profile.exists) throw new HttpsError('not-found', 'Profile is unavailable.');

    const isOwner = requesterUid === ownerUid;
    const matched = isOwner ? true : await hasActiveMatch(requesterUid, ownerUid);
    const mapVisibility = String(profile.get('mapVisibility') ?? 'private');
    if (!isOwner) {
      if (mapVisibility === 'private') {
        throw new HttpsError('permission-denied', 'Circle is private.');
      }
      if (mapVisibility === 'matches_only' && !matched) {
        throw new HttpsError('permission-denied', 'Circle is available to connections only.');
      }
      if (mapVisibility !== 'public' && mapVisibility !== 'matches_only') {
        throw new HttpsError('permission-denied', 'Circle is unavailable.');
      }
    }

    const snapshot = await db.collection('relationship_cards')
      .where('ownerUid', '==', ownerUid)
      .limit(100)
      .get();

    const cards: FirebaseFirestore.DocumentData[] = [];
    for (const card of snapshot.docs) {
      if (card.get('isActive') !== true) continue;
      const visibility = String(card.get('visibility') ?? 'private');

      if (isOwner) {
        cards.push(safeCard(card, false));
        continue;
      }
      if (visibility === 'private') continue;
      if (visibility === 'matches_only' && !matched) continue;
      if (visibility !== 'public' && visibility !== 'matches_only' && visibility !== 'unnamed_public') continue;

      // unnamed_public deliberately removes both the optional name and free-text
      // note because either field could identify a person indirectly.
      cards.push(safeCard(card, visibility === 'unnamed_public'));
    }

    cards.sort((a, b) => Number(a.sortOrder ?? 0) - Number(b.sortOrder ?? 0));
    return {ownerUid, cards};
  },
);
