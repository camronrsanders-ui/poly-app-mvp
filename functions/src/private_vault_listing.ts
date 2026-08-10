import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {assertPrivateVaultEnabled} from './private_vault_gate';

const db = getFirestore();
const maxRequestsPerDirection = 50;
const maxGrantsPerListing = 100;

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  assertPrivateVaultEnabled();
  return auth.uid;
}

async function assertActive(uid: string): Promise<void> {
  const user = await db.collection('users').doc(uid).get();
  if (!user.exists || user.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

async function consumeRateLimit(uid: string, action: string, max = 20): Promise<void> {
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
    if (count >= max) {
      throw new HttpsError('resource-exhausted', 'Too many requests. Try again later.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

function pairId(a: string, b: string): string {
  return [a, b].sort().join('_');
}

function millis(value: unknown): number | null {
  if (value && typeof (value as {toMillis?: unknown}).toMillis === 'function') {
    return (value as {toMillis: () => number}).toMillis();
  }
  return null;
}

type PeerContext = {
  eligible: Set<string>;
  displayNames: Map<string, string>;
};

function peerFromBlock(uid: string, snap: FirebaseFirestore.DocumentSnapshot): string | null {
  if (!snap.exists) return null;
  const blockerUid = String(snap.get('blockerUid') ?? '');
  const blockedUid = String(snap.get('blockedUid') ?? '');
  if (blockerUid === uid && blockedUid) return blockedUid;
  if (blockedUid === uid && blockerUid) return blockerUid;
  return null;
}

async function loadPeerContext(uid: string, rawPeerUids: string[]): Promise<PeerContext> {
  const peers = [...new Set(rawPeerUids)]
    .filter((peerUid) => peerUid.length > 0 && peerUid !== uid)
    .slice(0, maxRequestsPerDirection * 2);
  if (peers.length === 0) return {eligible: new Set(), displayNames: new Map()};

  const userRefs = peers.map((peerUid) => db.collection('users').doc(peerUid));
  const profileRefs = peers.map((peerUid) => db.collection('profiles').doc(peerUid));
  const blockRefs = peers.flatMap((peerUid) => [
    db.collection('blocks').doc(`${uid}_${peerUid}`),
    db.collection('blocks').doc(`${peerUid}_${uid}`),
  ]);
  const matchRefs = peers.map((peerUid) => db.collection('matches').doc(pairId(uid, peerUid)));

  const [users, profiles, blocks, matches] = await Promise.all([
    db.getAll(...userRefs),
    db.getAll(...profileRefs),
    db.getAll(...blockRefs),
    db.getAll(...matchRefs),
  ]);

  const activePeers = new Set(users
    .filter((snap) => snap.exists && snap.get('accountStatus') === 'active')
    .map((snap) => snap.id));
  const blockedPeers = new Set(blocks
    .map((snap) => peerFromBlock(uid, snap))
    .filter((peerUid): peerUid is string => peerUid !== null));
  const matchedPeers = new Set<string>();
  for (const match of matches) {
    if (!match.exists || match.get('active') !== true) continue;
    const userAUid = String(match.get('userAUid') ?? '');
    const userBUid = String(match.get('userBUid') ?? '');
    if (userAUid === uid && peers.includes(userBUid)) matchedPeers.add(userBUid);
    if (userBUid === uid && peers.includes(userAUid)) matchedPeers.add(userAUid);
  }

  const displayNames = new Map(profiles.map((profile) => {
    const raw = profile.exists ? profile.get('displayName') : null;
    const name = typeof raw === 'string' && raw.trim()
      ? raw.trim().slice(0, 80)
      : 'Connection';
    return [profile.id, name];
  }));
  const eligible = new Set(peers.filter((peerUid) =>
    activePeers.has(peerUid) && matchedPeers.has(peerUid) && !blockedPeers.has(peerUid),
  ));

  return {eligible, displayNames};
}

async function loadAcceptedRecipients(ownerUid: string, rawRecipientUids: string[]): Promise<Set<string>> {
  const recipients = [...new Set(rawRecipientUids)]
    .filter((recipientUid) => recipientUid.length > 0 && recipientUid !== ownerUid)
    .slice(0, maxGrantsPerListing);
  if (recipients.length === 0) return new Set();

  const requestRefs = recipients.map((recipientUid) =>
    db.collection('private_media_requests').doc(`${recipientUid}_${ownerUid}`));
  const requests = await db.getAll(...requestRefs);
  const accepted = new Set<string>();
  for (const request of requests) {
    if (!request.exists || request.get('status') !== 'accepted') continue;
    const requesterUid = String(request.get('requesterUid') ?? '');
    const recipientUid = String(request.get('recipientUid') ?? '');
    if (recipientUid === ownerUid && recipients.includes(requesterUid)) accepted.add(requesterUid);
  }
  return accepted;
}

export const listMyPrivateMediaRequests = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const uid = requireUid(request.auth);
    await Promise.all([
      assertActive(uid),
      consumeRateLimit(uid, 'private_media_request_list'),
    ]);

    const [outgoing, incoming] = await Promise.all([
      db.collection('private_media_requests').where('requesterUid', '==', uid).limit(maxRequestsPerDirection).get(),
      db.collection('private_media_requests').where('recipientUid', '==', uid).limit(maxRequestsPerDirection).get(),
    ]);

    const records = [...outgoing.docs, ...incoming.docs]
      .map((snap) => {
        const requesterUid = String(snap.get('requesterUid') ?? '');
        const recipientUid = String(snap.get('recipientUid') ?? '');
        if (!requesterUid || !recipientUid) return null;
        const otherUid = requesterUid === uid ? recipientUid : requesterUid;
        if (!otherUid || otherUid === uid) return null;
        return {snap, requesterUid, otherUid};
      })
      .filter((record): record is NonNullable<typeof record> => record !== null);

    const context = await loadPeerContext(uid, records.map(({otherUid}) => otherUid));
    const items = records
      .filter(({otherUid}) => context.eligible.has(otherUid))
      .map(({snap, requesterUid, otherUid}) => ({
        requestId: snap.id,
        direction: requesterUid === uid ? 'outgoing' : 'incoming',
        otherUid,
        otherDisplayName: context.displayNames.get(otherUid) ?? 'Connection',
        status: String(snap.get('status') ?? 'unknown'),
        createdAtMs: millis(snap.get('createdAt')),
        respondedAtMs: millis(snap.get('respondedAt')),
        cancelledAtMs: millis(snap.get('cancelledAt')),
      }));
    return {requests: items};
  },
);

export const listMyPrivateMediaShares = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const ownerUid = requireUid(request.auth);
    await Promise.all([
      assertActive(ownerUid),
      consumeRateLimit(ownerUid, 'private_media_share_list'),
    ]);

    const grants = await db.collection('private_media_grants')
      .where('ownerUid', '==', ownerUid)
      .where('active', '==', true)
      .limit(maxGrantsPerListing)
      .get();
    const records = grants.docs
      .map((grant) => ({
        grant,
        recipientUid: String(grant.get('recipientUid') ?? ''),
        mediaId: String(grant.get('mediaId') ?? ''),
      }))
      .filter(({recipientUid, mediaId}) => recipientUid.length > 0 && mediaId.length > 0);
    const [context, acceptedRecipients] = await Promise.all([
      loadPeerContext(ownerUid, records.map(({recipientUid}) => recipientUid)),
      loadAcceptedRecipients(ownerUid, records.map(({recipientUid}) => recipientUid)),
    ]);

    const shares = records
      .filter(({recipientUid}) => context.eligible.has(recipientUid) && acceptedRecipients.has(recipientUid))
      .map(({grant, recipientUid, mediaId}) => ({
        grantId: grant.id,
        mediaId,
        recipientUid,
        recipientDisplayName: context.displayNames.get(recipientUid) ?? 'Connection',
        createdAtMs: millis(grant.get('createdAt')),
      }));
    return {shares};
  },
);

export const listMyPrivateMediaInbox = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const recipientUid = requireUid(request.auth);
    await Promise.all([
      assertActive(recipientUid),
      consumeRateLimit(recipientUid, 'private_media_inbox_list'),
    ]);

    const grants = await db.collection('private_media_grants')
      .where('recipientUid', '==', recipientUid)
      .where('active', '==', true)
      .limit(maxGrantsPerListing)
      .get();
    const records = grants.docs
      .map((grant) => ({
        grant,
        ownerUid: String(grant.get('ownerUid') ?? ''),
        mediaId: String(grant.get('mediaId') ?? ''),
      }))
      .filter(({ownerUid, mediaId}) => ownerUid.length > 0 && mediaId.length > 0);
    const context = await loadPeerContext(recipientUid, records.map(({ownerUid}) => ownerUid));
    const ownerUids = [...new Set(records.map(({ownerUid}) => ownerUid))];
    const acceptedByOwner = new Map<string, boolean>();
    await Promise.all(ownerUids.map(async (ownerUid) => {
      const accepted = await loadAcceptedRecipients(ownerUid, [recipientUid]);
      acceptedByOwner.set(ownerUid, accepted.has(recipientUid));
    }));
    const eligibleRecords = records.filter(({ownerUid}) =>
      context.eligible.has(ownerUid) && acceptedByOwner.get(ownerUid) === true);
    if (eligibleRecords.length === 0) return {media: []};

    const mediaRefs = eligibleRecords.map(({mediaId}) => db.collection('private_media').doc(mediaId));
    const mediaDocs = await db.getAll(...mediaRefs);
    const mediaById = new Map(mediaDocs.map((media) => [media.id, media]));

    const mediaItems = eligibleRecords
      .filter(({ownerUid, mediaId}) => {
        const media = mediaById.get(mediaId);
        return media?.exists === true
          && media.get('ownerUid') === ownerUid
          && media.get('status') === 'active';
      })
      .map(({grant, ownerUid, mediaId}) => ({
        mediaId,
        ownerUid,
        ownerDisplayName: context.displayNames.get(ownerUid) ?? 'Connection',
        grantedAtMs: millis(grant.get('createdAt')),
      }));
    return {media: mediaItems};
  },
);
