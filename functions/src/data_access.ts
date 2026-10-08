import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

const db = getFirestore();

type Doc = FirebaseFirestore.QueryDocumentSnapshot | FirebaseFirestore.DocumentSnapshot;

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

async function assertActive(uid: string): Promise<void> {
  const account = await db.collection('users').doc(uid).get();
  if (!account.exists || account.get('accountStatus') !== 'active') {
    throw new HttpsError('permission-denied', 'Account is not active.');
  }
}

function requireRecentAuth(auth: {token?: Record<string, unknown>} | undefined): void {
  const authTime = Number(auth?.token?.auth_time ?? 0) * 1000;
  if (!authTime || Date.now() - authTime > 10 * 60_000) {
    throw new HttpsError('failed-precondition', 'Please sign in again before requesting your data snapshot.');
  }
}

async function consumeRateLimit(uid: string): Promise<void> {
  const action = 'data_snapshot';
  const max = 3;
  const windowMs = 24 * 60 * 60_000;
  const ref = db.collection('_rate_limits').doc(`${action}_${uid}`);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const start = Number(snap.get('windowStartMs') ?? 0);
    const count = Number(snap.get('count') ?? 0);
    if (!snap.exists || now - start >= windowMs) {
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
      throw new HttpsError('resource-exhausted', 'Please wait before requesting another data snapshot.');
    }
    tx.set(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  });
}

function timestampMillis(value: unknown): number | null {
  const candidate = value as {toMillis?: () => number} | null | undefined;
  return candidate?.toMillis?.() ?? null;
}

function text(value: unknown, max: number): string {
  return typeof value === 'string' ? value.slice(0, max) : '';
}

function strings(value: unknown, maxItems: number, maxItemLength = 120): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === 'string')
    .map((item) => item.slice(0, maxItemLength))
    .slice(0, maxItems);
}

function ownAccount(doc: Doc): Record<string, unknown> | null {
  if (!doc.exists) return null;
  return {
    uid: doc.id,
    email: text(doc.get('email'), 320),
    onboardingComplete: doc.get('onboardingComplete') === true,
    accountStatus: text(doc.get('accountStatus'), 40),
    createdAtMs: timestampMillis(doc.get('createdAt')),
    lastActiveAtMs: timestampMillis(doc.get('lastActiveAt')),
  };
}

function ownProfile(doc: Doc): Record<string, unknown> | null {
  if (!doc.exists) return null;
  return {
    uid: doc.id,
    displayName: text(doc.get('displayName'), 80),
    age: Number.isInteger(doc.get('age')) ? doc.get('age') : null,
    city: text(doc.get('city'), 100),
    region: text(doc.get('region'), 100),
    bio: text(doc.get('bio'), 1500),
    headline: text(doc.get('headline'), 160),
    genderIdentity: text(doc.get('genderIdentity'), 100),
    pronouns: text(doc.get('pronouns'), 100),
    orientation: text(doc.get('orientation'), 100),
    customIdentityTags: strings(doc.get('customIdentityTags'), 12, 100),
    relationshipStructure: text(doc.get('relationshipStructure'), 120),
    relationshipStatus: text(doc.get('relationshipStatus'), 120),
    partnered: doc.get('partnered') === true,
    openToConnections: doc.get('openToConnections') === true,
    intentionTags: strings(doc.get('intentionTags'), 12, 100),
    interests: strings(doc.get('interests'), 20, 100),
    lookingForNote: text(doc.get('lookingForNote'), 1200),
    ageMin: Number.isInteger(doc.get('ageMin')) ? doc.get('ageMin') : null,
    ageMax: Number.isInteger(doc.get('ageMax')) ? doc.get('ageMax') : null,
    distanceRadius: Number.isInteger(doc.get('distanceRadius')) ? doc.get('distanceRadius') : null,
    preferredStructures: strings(doc.get('preferredStructures'), 12, 120),
    preferredIntentions: strings(doc.get('preferredIntentions'), 12, 100),
    profileVisibility: text(doc.get('profileVisibility'), 40),
    mapVisibility: text(doc.get('mapVisibility'), 40),
    createdAtMs: timestampMillis(doc.get('createdAt')),
    updatedAtMs: timestampMillis(doc.get('updatedAt')),
  };
}

function ownDiscoverLocation(doc: Doc): Record<string, unknown> | null {
  if (!doc.exists) return null;
  const latitude = Number(doc.get('latitude'));
  const longitude = Number(doc.get('longitude'));
  const accuracyMeters = Number(doc.get('accuracyMeters'));
  return {
    // This callable is a recent-auth snapshot of the requester's own data. It
    // is deliberately separate from every cross-user profile view.
    latitude: Number.isFinite(latitude) ? latitude : null,
    longitude: Number.isFinite(longitude) ? longitude : null,
    accuracyMeters: Number.isFinite(accuracyMeters) ? accuracyMeters : null,
    source: text(doc.get('source'), 40),
    observedAtMs: timestampMillis(doc.get('observedAt')),
    updatedAtMs: timestampMillis(doc.get('updatedAt')),
  };
}

const exportLimits = {
  relationshipCards: 200,
  likes: 500,
  passes: 500,
  matchesPerSide: 300,
  conversations: 300,
  sentMessages: 1000,
  blocks: 500,
  reports: 500,
  profileMedia: 100,
  privateMedia: 100,
} as const;

function hitLimit(size: number, limit: number): boolean {
  return size >= limit;
}

export const getMyDataSnapshot = onCall(
  {enforceAppCheck: true, maxInstances: 10},
  async (request) => {
    const uid = requireUid(request.auth);
    requireRecentAuth(request.auth);
    await Promise.all([assertActive(uid), consumeRateLimit(uid)]);

    const [
      account,
      profile,
      discoverLocation,
      cards,
      likes,
      passes,
      matchesA,
      matchesB,
      conversations,
      sentMessages,
      blocks,
      reports,
      profileMedia,
      privateMedia,
    ] = await Promise.all([
      db.collection('users').doc(uid).get(),
      db.collection('profiles').doc(uid).get(),
      db.collection('member_locations').doc(uid).get(),
      db.collection('relationship_cards').where('ownerUid', '==', uid).limit(exportLimits.relationshipCards).get(),
      db.collection('likes').where('fromUid', '==', uid).limit(exportLimits.likes).get(),
      db.collection('profile_passes').where('fromUid', '==', uid).limit(exportLimits.passes).get(),
      db.collection('matches').where('userAUid', '==', uid).limit(exportLimits.matchesPerSide).get(),
      db.collection('matches').where('userBUid', '==', uid).limit(exportLimits.matchesPerSide).get(),
      db.collection('conversations').where('participantUids', 'array-contains', uid).limit(exportLimits.conversations).get(),
      db.collection('messages').where('senderUid', '==', uid).limit(exportLimits.sentMessages).get(),
      db.collection('blocks').where('blockerUid', '==', uid).limit(exportLimits.blocks).get(),
      db.collection('reports').where('reporterUid', '==', uid).limit(exportLimits.reports).get(),
      db.collection('profile_media').where('ownerUid', '==', uid).limit(exportLimits.profileMedia).get(),
      db.collection('private_media').where('ownerUid', '==', uid).limit(exportLimits.privateMedia).get(),
    ]);

    const matchesById = new Map([...matchesA.docs, ...matchesB.docs].map((doc) => [doc.id, doc]));
    const truncated = [
      hitLimit(cards.size, exportLimits.relationshipCards) ? 'relationshipCards' : null,
      hitLimit(likes.size, exportLimits.likes) ? 'likes' : null,
      hitLimit(passes.size, exportLimits.passes) ? 'passes' : null,
      (hitLimit(matchesA.size, exportLimits.matchesPerSide) || hitLimit(matchesB.size, exportLimits.matchesPerSide)) ? 'matches' : null,
      hitLimit(conversations.size, exportLimits.conversations) ? 'conversations' : null,
      hitLimit(sentMessages.size, exportLimits.sentMessages) ? 'sentMessages' : null,
      hitLimit(blocks.size, exportLimits.blocks) ? 'blocks' : null,
      hitLimit(reports.size, exportLimits.reports) ? 'reports' : null,
      hitLimit(profileMedia.size, exportLimits.profileMedia) ? 'profileMedia' : null,
      hitLimit(privateMedia.size, exportLimits.privateMedia) ? 'privateMedia' : null,
    ].filter((value): value is string => value !== null);

    return {
      generatedAtMs: Date.now(),
      snapshotIsBounded: true,
      truncatedCategories: truncated,
      account: ownAccount(account),
      profile: ownProfile(profile),
      discoverLocation: ownDiscoverLocation(discoverLocation),
      relationshipCards: cards.docs.map((doc) => ({
        cardId: doc.id,
        label: text(doc.get('label'), 100),
        connectionType: text(doc.get('connectionType'), 100),
        displayNameOptional: text(doc.get('displayNameOptional'), 100),
        status: text(doc.get('status'), 80),
        note: text(doc.get('note'), 1000),
        visibility: text(doc.get('visibility'), 40),
        sortOrder: Number(doc.get('sortOrder') ?? 0),
        isActive: doc.get('isActive') === true,
        createdAtMs: timestampMillis(doc.get('createdAt')),
        updatedAtMs: timestampMillis(doc.get('updatedAt')),
      })),
      outgoingLikes: likes.docs.map((doc) => ({
        likeId: doc.id,
        toUid: text(doc.get('toUid'), 128),
        createdAtMs: timestampMillis(doc.get('createdAt')),
      })),
      passes: passes.docs.map((doc) => ({
        passId: doc.id,
        toUid: text(doc.get('toUid'), 128),
        createdAtMs: timestampMillis(doc.get('createdAt')),
      })),
      matches: [...matchesById.values()].map((doc) => ({
        matchId: doc.id,
        userAUid: text(doc.get('userAUid'), 128),
        userBUid: text(doc.get('userBUid'), 128),
        active: doc.get('active') === true,
        createdAtMs: timestampMillis(doc.get('createdAt')),
        endedAtMs: timestampMillis(doc.get('endedAt')),
        endedReason: text(doc.get('endedReason'), 80),
      })),
      conversations: conversations.docs.map((doc) => ({
        conversationId: doc.id,
        participantUids: strings(doc.get('participantUids'), 2, 128),
        active: doc.get('active') === true,
        createdAtMs: timestampMillis(doc.get('createdAt')),
        lastMessageAtMs: timestampMillis(doc.get('lastMessageAt')),
        endedAtMs: timestampMillis(doc.get('endedAt')),
        endedReason: text(doc.get('endedReason'), 80),
      })),
      sentMessages: sentMessages.docs.map((doc) => ({
        messageId: doc.id,
        conversationId: text(doc.get('conversationId'), 128),
        text: text(doc.get('text'), 2000),
        messageType: text(doc.get('messageType'), 40),
        isDeleted: doc.get('isDeleted') === true,
        createdAtMs: timestampMillis(doc.get('createdAt')),
      })),
      blocks: blocks.docs.map((doc) => ({
        blockId: doc.id,
        blockedUid: text(doc.get('blockedUid'), 128),
        createdAtMs: timestampMillis(doc.get('createdAt')),
      })),
      reportsSubmitted: reports.docs.map((doc) => ({
        reportId: doc.id,
        reportedUid: text(doc.get('reportedUid'), 128),
        reason: text(doc.get('reason'), 80),
        details: text(doc.get('details'), 2000),
        status: text(doc.get('status'), 40),
        createdAtMs: timestampMillis(doc.get('createdAt')),
        reviewedAtMs: timestampMillis(doc.get('reviewedAt')),
      })),
      profileMedia: profileMedia.docs.map((doc) => ({
        photoId: doc.id,
        status: text(doc.get('status'), 60),
        contentType: text(doc.get('contentType'), 80),
        createdAtMs: timestampMillis(doc.get('createdAt')),
        processedAtMs: timestampMillis(doc.get('processedAt')),
        reviewedAtMs: timestampMillis(doc.get('reviewedAt')),
      })),
      privateMedia: privateMedia.docs.map((doc) => ({
        mediaId: doc.id,
        status: text(doc.get('status'), 60),
        contentType: text(doc.get('contentType'), 80),
        createdAtMs: timestampMillis(doc.get('createdAt')),
        processedAtMs: timestampMillis(doc.get('processedAt')),
      })),
    };
  },
);
