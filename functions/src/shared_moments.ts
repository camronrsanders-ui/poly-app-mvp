import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {assertActiveCompliantMember} from './account_compliance';
import {
  normalizeSharedMomentInput,
  SharedMomentInput,
} from './shared_moment_fields';
import {safeSharedMomentMessagePreview} from './shared_moment_preview';

// Keep the write path fail-closed until the Shared Moments UI is approved and
// protected photo-moment media has a complete moderation/delivery lifecycle.
const SHARED_MOMENTS_CREATE_ENABLED = false;
const DISPLAYABLE_SHARED_MOMENT_KINDS = new Set(['note', 'place', 'message']);

function requireUid(auth: {uid: string} | undefined): string {
  if (!auth?.uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return auth.uid;
}

function requireReference(raw: unknown, label: string): string {
  const value = String(raw ?? '').trim();
  if (!value || value.length > 128 || !/^[A-Za-z0-9:_-]+$/.test(value)) {
    throw new HttpsError('invalid-argument', `Invalid ${label}.`);
  }
  return value;
}

function storedReference(raw: unknown): string {
  const value = String(raw ?? '').trim();
  if (!value || value.length > 128 || !/^[A-Za-z0-9:_-]+$/.test(value)) {
    return '';
  }
  return value;
}

function timestampMillis(value: unknown): number | null {
  const candidate = value as {toMillis?: () => number} | null | undefined;
  return candidate?.toMillis?.() ?? null;
}

async function enforceRateLimit(
  uid: string,
  action: string,
  max: number,
  windowMs: number,
): Promise<void> {
  const db = getFirestore();
  const ref = db.collection('_rate_limits').doc(`${action}_${uid}`);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const start = snap.get('windowStart')?.toMillis?.() ?? 0;
    const count = Number(snap.get('count') ?? 0);
    if (!snap.exists || now - start >= windowMs) {
      tx.set(ref, {
        uid,
        action,
        count: 1,
        windowStart: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }
    if (count >= max) {
      throw new HttpsError('resource-exhausted', 'Please wait a moment and try again.');
    }
    tx.update(ref, {count: count + 1, updatedAt: FieldValue.serverTimestamp()});
  });
}

async function conversationForMember(
  db: FirebaseFirestore.Firestore,
  conversationId: string,
  uid: string,
  requireActive: boolean,
): Promise<FirebaseFirestore.DocumentSnapshot> {
  const conversation = await db.collection('conversations').doc(conversationId).get();
  if (!conversation.exists) {
    throw new HttpsError('not-found', 'Conversation not found.');
  }
  const participantUids = conversation.get('participantUids');
  if (!Array.isArray(participantUids)
      || participantUids.length !== 2
      || !participantUids.includes(uid)) {
    throw new HttpsError(
      'permission-denied',
      'Shared moments are available only to conversation participants.',
    );
  }
  if (requireActive && conversation.get('active') !== true) {
    throw new HttpsError('failed-precondition', 'This conversation is no longer active.');
  }

  if (requireActive) {
    await Promise.all(
      participantUids.map((participantUid) =>
        assertActiveCompliantMember(db, String(participantUid))),
    );
    const [forward, reverse] = await db.getAll(
      db.collection('blocks').doc(`${participantUids[0]}_${participantUids[1]}`),
      db.collection('blocks').doc(`${participantUids[1]}_${participantUids[0]}`),
    );
    if (forward.exists || reverse.exists) {
      throw new HttpsError('permission-denied', 'This conversation is unavailable.');
    }
  }

  return conversation;
}

async function assertSavableSourceMessage(
  db: FirebaseFirestore.Firestore,
  conversationId: string,
  sourceMessageId: string,
): Promise<void> {
  const source = await db.collection('messages').doc(sourceMessageId).get();
  if (!source.exists
      || source.get('conversationId') !== conversationId
      || source.get('messageType') !== 'text'
      || source.get('isDeleted') === true) {
    throw new HttpsError('not-found', 'The message to save is unavailable.');
  }
}

export const createSharedMoment = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const uid = requireUid(request.auth);
    if (!SHARED_MOMENTS_CREATE_ENABLED) {
      throw new HttpsError(
        'failed-precondition',
        'Shared Moments are not enabled in this build.',
      );
    }

    const db = getFirestore();
    const conversationId = requireReference(
      request.data?.conversationId,
      'conversation reference',
    );
    await Promise.all([
      assertActiveCompliantMember(db, uid),
      enforceRateLimit(uid, 'shared_moment_create', 30, 60 * 60_000),
    ]);
    await conversationForMember(db, conversationId, uid, true);

    let input: SharedMomentInput;
    try {
      input = normalizeSharedMomentInput(request.data);
    } catch (error) {
      const message = error instanceof Error
        ? error.message
        : 'Invalid shared moment.';
      throw new HttpsError('invalid-argument', message);
    }

    // Photo moments are part of the approved product direction, but must not
    // ship until they use a protected moderation/delivery lifecycle rather than
    // raw client URLs or Storage paths.
    if (input.kind === 'photo') {
      throw new HttpsError(
        'failed-precondition',
        'Photo moments are not available until protected shared-media handling is ready.',
      );
    }
    if (input.kind === 'message') {
      await assertSavableSourceMessage(db, conversationId, input.sourceMessageId);
    }

    const ref = db.collection('messages').doc();
    await ref.set({
      conversationId,
      senderUid: uid,
      text: input.title,
      createdAt: FieldValue.serverTimestamp(),
      isDeleted: false,
      messageType: 'shared_moment',
      readBy: [uid],
      momentKind: input.kind,
      momentTitle: input.title,
      momentNote: input.note,
      ...(input.kind === 'place' ? {placeLabel: input.placeLabel} : {}),
      ...(input.kind === 'message'
        ? {sourceMessageId: input.sourceMessageId}
        : {}),
    });

    return {momentId: ref.id};
  },
);

export const listSharedMoments = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);
    const conversationId = requireReference(
      request.data?.conversationId,
      'conversation reference',
    );
    await Promise.all([
      assertActiveCompliantMember(db, uid),
      enforceRateLimit(uid, 'shared_moment_list', 120, 60 * 60_000),
    ]);
    await conversationForMember(db, conversationId, uid, true);

    const snapshot = await db.collection('messages')
      .where('conversationId', '==', conversationId)
      .where('messageType', '==', 'shared_moment')
      .orderBy('createdAt', 'desc')
      .limit(100)
      .get();

    // Read paths stay narrower than the reserved data model. Unknown kinds and
    // photo moments remain invisible until a protected photo lifecycle exists.
    const momentDocs = snapshot.docs.filter((doc) =>
      DISPLAYABLE_SHARED_MOMENT_KINDS.has(String(doc.get('momentKind') ?? '').trim()),
    );
    const sourceMessageIds = new Set<string>();
    for (const moment of momentDocs) {
      if (String(moment.get('momentKind') ?? '') !== 'message') continue;
      const sourceMessageId = storedReference(moment.get('sourceMessageId'));
      if (sourceMessageId) sourceMessageIds.add(sourceMessageId);
    }

    const sourceMessagePreviews = new Map<
      string,
      ReturnType<typeof safeSharedMomentMessagePreview>
    >();
    if (sourceMessageIds.size > 0) {
      const sources = await db.getAll(
        ...Array.from(sourceMessageIds, (sourceMessageId) =>
          db.collection('messages').doc(sourceMessageId)),
      );
      for (const source of sources) {
        const preview = safeSharedMomentMessagePreview(
          source.data(),
          conversationId,
        );
        if (preview.text) sourceMessagePreviews.set(source.id, preview);
      }
    }

    return {
      moments: momentDocs.map((doc) => {
        const sourceMessageId = storedReference(doc.get('sourceMessageId'));
        const sourcePreview = sourceMessagePreviews.get(sourceMessageId);
        return {
          momentId: doc.id,
          creatorUid: String(doc.get('senderUid') ?? ''),
          kind: String(doc.get('momentKind') ?? ''),
          title: String(doc.get('momentTitle') ?? ''),
          note: String(doc.get('momentNote') ?? ''),
          placeLabel: String(doc.get('placeLabel') ?? ''),
          sourceMessageId,
          sourceMessagePreview: sourcePreview?.text ?? '',
          sourceMessageFromCaller: sourcePreview?.senderUid === uid,
          createdAtMs: timestampMillis(doc.get('createdAt')),
        };
      }),
    };
  },
);

export const deleteSharedMoment = onCall(
  {enforceAppCheck: true, maxInstances: 20},
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);
    const conversationId = requireReference(
      request.data?.conversationId,
      'conversation reference',
    );
    const momentId = requireReference(request.data?.momentId, 'moment reference');
    await Promise.all([
      assertActiveCompliantMember(db, uid),
      enforceRateLimit(uid, 'shared_moment_delete', 60, 60 * 60_000),
    ]);
    await conversationForMember(db, conversationId, uid, false);

    const ref = db.collection('messages').doc(momentId);
    const moment = await ref.get();
    if (!moment.exists
        || moment.get('messageType') !== 'shared_moment'
        || moment.get('conversationId') !== conversationId
        || moment.get('senderUid') !== uid) {
      throw new HttpsError('not-found', 'Shared moment not found.');
    }

    await ref.delete();
    return {deleted: true};
  },
);
