import {
  FieldValue,
  getFirestore,
} from 'firebase-admin/firestore';

import {
  HttpsError,
  onCall,
} from 'firebase-functions/v2/https';

import {
  assertActiveCompliantMember,
  isActiveCompliantMember,
} from './account_compliance';

function requireUid(
  auth: {uid: string} | undefined,
): string {
  if (!auth?.uid) {
    throw new HttpsError(
      'unauthenticated',
      'Sign in required.',
    );
  }

  return auth.uid;
}

function requireId(
  raw: unknown,
  label: string,
): string {
  const value = String(raw ?? '').trim();

  if (
    !value ||
    value.length > 128 ||
    !/^[A-Za-z0-9:_-]+$/.test(value)
  ) {
    throw new HttpsError(
      'invalid-argument',
      `Invalid ${label}.`,
    );
  }

  return value;
}

function requireCircleName(
  raw: unknown,
): string {
  const name = String(raw ?? '')
    .trim()
    .replace(/\s+/g, ' ');

  if (
    !name ||
    name.length > 60 ||
    /[\u0000-\u001F\u007F]/.test(name)
  ) {
    throw new HttpsError(
      'invalid-argument',
      'Circle names must be between 1 and 60 characters.',
    );
  }

  return name;
}

function pairId(
  a: string,
  b: string,
): string {
  return [a, b].sort().join('_');
}

function membershipId(
  circleId: string,
  uid: string,
): string {
  return `${circleId}_${uid}`;
}

function inviteId(
  circleId: string,
  uid: string,
): string {
  return `${circleId}_${uid}`;
}

async function consumeCircleRateLimit(
  uid: string,
  action: string,
  maximum: number,
  windowMs: number,
): Promise<void> {
  const db = getFirestore();

  const ref = db
    .collection('_rate_limits')
    .doc(`circle_${action}_${uid}`);

  const now = Date.now();

  await db.runTransaction(
    async (tx) => {
      const snap = await tx.get(ref);

      const windowStartMs = Number(
        snap.get('windowStartMs') ?? 0,
      );

      const count = Number(
        snap.get('count') ?? 0,
      );

      if (
        !snap.exists ||
        now - windowStartMs >= windowMs
      ) {
        tx.set(ref, {
          uid,
          action: `circle_${action}`,
          windowStartMs: now,
          count: 1,
          updatedAt:
            FieldValue.serverTimestamp(),
        });

        return;
      }

      if (count >= maximum) {
        throw new HttpsError(
          'resource-exhausted',
          'Please wait before trying that Circle action again.',
        );
      }

      tx.update(ref, {
        count: count + 1,
        updatedAt:
          FieldValue.serverTimestamp(),
      });
    },
  );
}

/**
 * Create a Circle.
 *
 * Creation gives membership ONLY to its creator.
 * Nobody else can be silently inserted.
 */
export const createCircle = onCall(
  {
    enforceAppCheck: true,
    maxInstances: 20,
  },
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);

    const name = requireCircleName(
      request.data?.name,
    );

    await Promise.all([
      assertActiveCompliantMember(
        db,
        uid,
      ),
      consumeCircleRateLimit(
        uid,
        'create',
        10,
        60 * 60_000,
      ),
    ]);

    const circleRef =
      db.collection('circles').doc();

    const ownerMembershipRef = db
      .collection('circle_memberships')
      .doc(
        membershipId(
          circleRef.id,
          uid,
        ),
      );

    await db.runTransaction(
      async (tx) => {
        tx.set(circleRef, {
          circleId: circleRef.id,
          ownerUid: uid,
          name,
          status: 'active',
          visibility: 'private',

          createdAt:
            FieldValue.serverTimestamp(),

          updatedAt:
            FieldValue.serverTimestamp(),
        });

        tx.set(ownerMembershipRef, {
          circleId: circleRef.id,
          uid,

          role: 'owner',
          status: 'active',

          joinedAt:
            FieldValue.serverTimestamp(),

          acceptedAt:
            FieldValue.serverTimestamp(),

          createdAt:
            FieldValue.serverTimestamp(),

          updatedAt:
            FieldValue.serverTimestamp(),
        });
      },
    );

    return {
      circleId: circleRef.id,
      name,
      role: 'owner',
    };
  },
);

/**
 * Invite an existing active connection.
 *
 * IMPORTANT:
 * This creates a pending invitation,
 * NOT membership.
 */
export const inviteCircleMember = onCall(
  {
    enforceAppCheck: true,
    maxInstances: 20,
  },
  async (request) => {
    const db = getFirestore();

    const inviterUid =
      requireUid(request.auth);

    const circleIdValue =
      requireId(
        request.data?.circleId,
        'Circle',
      );

    const inviteeUid =
      requireId(
        request.data?.inviteeUid,
        'invitee',
      );

    if (inviteeUid === inviterUid) {
      throw new HttpsError(
        'invalid-argument',
        'You cannot invite yourself.',
      );
    }

    await Promise.all([
      assertActiveCompliantMember(
        db,
        inviterUid,
      ),

      assertActiveCompliantMember(
        db,
        inviteeUid,
      ),

      consumeCircleRateLimit(
        inviterUid,
        'invite',
        30,
        60 * 60_000,
      ),
    ]);

    const circleRef = db
      .collection('circles')
      .doc(circleIdValue);

    const matchRef = db
      .collection('matches')
      .doc(
        pairId(
          inviterUid,
          inviteeUid,
        ),
      );

    const outgoingBlockRef = db
      .collection('blocks')
      .doc(
        `${inviterUid}_${inviteeUid}`,
      );

    const incomingBlockRef = db
      .collection('blocks')
      .doc(
        `${inviteeUid}_${inviterUid}`,
      );

    const membershipRef = db
      .collection('circle_memberships')
      .doc(
        membershipId(
          circleIdValue,
          inviteeUid,
        ),
      );

    const invitationRef = db
      .collection('circle_invites')
      .doc(
        inviteId(
          circleIdValue,
          inviteeUid,
        ),
      );

    await db.runTransaction(
      async (tx) => {
        const [
          circle,
          match,
          outgoingBlock,
          incomingBlock,
          membership,
          existingInvite,
        ] = await Promise.all([
          tx.get(circleRef),
          tx.get(matchRef),
          tx.get(outgoingBlockRef),
          tx.get(incomingBlockRef),
          tx.get(membershipRef),
          tx.get(invitationRef),
        ]);

        if (!circle.exists) {
          throw new HttpsError(
            'not-found',
            'Circle was not found.',
          );
        }

        if (
          circle.get('status') !==
          'active'
        ) {
          throw new HttpsError(
            'failed-precondition',
            'This Circle is not active.',
          );
        }

        if (
          String(
            circle.get('ownerUid') ?? '',
          ) !== inviterUid
        ) {
          throw new HttpsError(
            'permission-denied',
            'Only the Circle owner can invite members.',
          );
        }

        if (
          outgoingBlock.exists ||
          incomingBlock.exists
        ) {
          throw new HttpsError(
            'permission-denied',
            'Circle invitation unavailable.',
          );
        }

        if (
          !match.exists ||
          match.get('active') !== true
        ) {
          throw new HttpsError(
            'failed-precondition',
            'Only an active connection can be invited to a Circle.',
          );
        }

        if (
          membership.exists &&
          membership.get('status') ===
            'active'
        ) {
          throw new HttpsError(
            'already-exists',
            'That person is already in this Circle.',
          );
        }

        if (
          existingInvite.exists &&
          existingInvite.get('status') ===
            'pending'
        ) {
          throw new HttpsError(
            'already-exists',
            'A Circle invitation is already pending.',
          );
        }

        tx.set(invitationRef, {
          inviteId: invitationRef.id,

          circleId: circleIdValue,

          ownerUid: inviterUid,
          inviterUid,
          inviteeUid,

          status: 'pending',

          createdAt:
            FieldValue.serverTimestamp(),

          updatedAt:
            FieldValue.serverTimestamp(),
        });
      },
    );

    return {
      invited: true,
      inviteId: invitationRef.id,
    };
  },
);

/**
 * Only the invitee can accept or decline.
 *
 * Membership becomes active ONLY here.
 */
export const respondToCircleInvite =
  onCall(
    {
      enforceAppCheck: true,
      maxInstances: 20,
    },
    async (request) => {
      const db = getFirestore();
      const uid = requireUid(
        request.auth,
      );

      const inviteIdValue =
        requireId(
          request.data?.inviteId,
          'Circle invitation',
        );

      const accept =
        request.data?.accept;

      if (
        typeof accept !== 'boolean'
      ) {
        throw new HttpsError(
          'invalid-argument',
          'Choose whether to accept or decline the invitation.',
        );
      }

      await Promise.all([
        assertActiveCompliantMember(
          db,
          uid,
        ),

        consumeCircleRateLimit(
          uid,
          'respond',
          40,
          60 * 60_000,
        ),
      ]);

      const invitationRef = db
        .collection('circle_invites')
        .doc(inviteIdValue);

      const accepted =
        await db.runTransaction(
          async (tx) => {
            const invitation =
              await tx.get(
                invitationRef,
              );

            if (
              !invitation.exists
            ) {
              throw new HttpsError(
                'not-found',
                'Circle invitation was not found.',
              );
            }

            if (
              String(
                invitation.get(
                  'inviteeUid',
                ) ?? '',
              ) !== uid
            ) {
              throw new HttpsError(
                'permission-denied',
                'This invitation is not yours.',
              );
            }

            if (
              invitation.get(
                'status',
              ) !== 'pending'
            ) {
              throw new HttpsError(
                'failed-precondition',
                'This Circle invitation is no longer pending.',
              );
            }

            if (!accept) {
              tx.update(
                invitationRef,
                {
                  status: 'declined',

                  declinedAt:
                    FieldValue.serverTimestamp(),

                  respondedAt:
                    FieldValue.serverTimestamp(),

                  updatedAt:
                    FieldValue.serverTimestamp(),
                },
              );

              return false;
            }

            const circleIdValue =
              requireId(
                invitation.get(
                  'circleId',
                ),
                'Circle',
              );

            const ownerUid =
              requireId(
                invitation.get(
                  'ownerUid',
                ),
                'Circle owner',
              );

            const circleRef = db
              .collection('circles')
              .doc(circleIdValue);

            const membershipRef = db
              .collection(
                'circle_memberships',
              )
              .doc(
                membershipId(
                  circleIdValue,
                  uid,
                ),
              );

            const matchRef = db
              .collection('matches')
              .doc(
                pairId(
                  ownerUid,
                  uid,
                ),
              );

            const ownerUserRef = db
              .collection('users')
              .doc(ownerUid);

            const ownerBlocksInvitee =
              db
                .collection('blocks')
                .doc(
                  `${ownerUid}_${uid}`,
                );

            const inviteeBlocksOwner =
              db
                .collection('blocks')
                .doc(
                  `${uid}_${ownerUid}`,
                );

            const [
              circle,
              membership,
              match,
              ownerUser,
              blockA,
              blockB,
            ] = await Promise.all([
              tx.get(circleRef),
              tx.get(membershipRef),
              tx.get(matchRef),
              tx.get(ownerUserRef),
              tx.get(
                ownerBlocksInvitee,
              ),
              tx.get(
                inviteeBlocksOwner,
              ),
            ]);

            if (
              !circle.exists ||
              circle.get('status') !==
                'active'
            ) {
              throw new HttpsError(
                'failed-precondition',
                'This Circle is no longer active.',
              );
            }

            if (
              String(
                circle.get(
                  'ownerUid',
                ) ?? '',
              ) !== ownerUid
            ) {
              throw new HttpsError(
                'failed-precondition',
                'Circle ownership changed.',
              );
            }

            if (
              !isActiveCompliantMember(
                ownerUser,
              )
            ) {
              throw new HttpsError(
                'permission-denied',
                'The Circle owner is unavailable.',
              );
            }

            if (
              !match.exists ||
              match.get('active') !==
                true
            ) {
              throw new HttpsError(
                'failed-precondition',
                'The connection is no longer active.',
              );
            }

            if (
              blockA.exists ||
              blockB.exists
            ) {
              throw new HttpsError(
                'permission-denied',
                'Circle membership is unavailable.',
              );
            }

            if (
              membership.exists &&
              membership.get(
                'status',
              ) === 'active'
            ) {
              throw new HttpsError(
                'already-exists',
                'You are already a member of this Circle.',
              );
            }

            const membershipData:
              FirebaseFirestore.DocumentData =
                {
                  circleId:
                    circleIdValue,

                  uid,

                  role: 'member',
                  status: 'active',

                  invitedByUid:
                    ownerUid,

                  joinedAt:
                    FieldValue.serverTimestamp(),

                  acceptedAt:
                    FieldValue.serverTimestamp(),

                  updatedAt:
                    FieldValue.serverTimestamp(),

                  leftAt:
                    FieldValue.delete(),
                };

            if (
              membership.exists
            ) {
              membershipData.rejoinedAt =
                FieldValue.serverTimestamp();
            } else {
              membershipData.createdAt =
                FieldValue.serverTimestamp();
            }

            tx.set(
              membershipRef,
              membershipData,
              {
                merge: true,
              },
            );

            tx.update(
              invitationRef,
              {
                status: 'accepted',

                acceptedAt:
                  FieldValue.serverTimestamp(),

                respondedAt:
                  FieldValue.serverTimestamp(),

                updatedAt:
                  FieldValue.serverTimestamp(),
              },
            );

            return true;
          },
        );

      return {
        accepted,
      };
    },
  );

/**
 * Members can leave without owner approval.
 *
 * The owner cannot leave until a later
 * archive/delete/transfer lifecycle exists.
 */
export const leaveCircle = onCall(
  {
    enforceAppCheck: true,
    maxInstances: 20,
  },
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);

    const circleIdValue =
      requireId(
        request.data?.circleId,
        'Circle',
      );

    await Promise.all([
      assertActiveCompliantMember(
        db,
        uid,
      ),

      consumeCircleRateLimit(
        uid,
        'leave',
        20,
        60 * 60_000,
      ),
    ]);

    const circleRef = db
      .collection('circles')
      .doc(circleIdValue);

    const membershipRef = db
      .collection('circle_memberships')
      .doc(
        membershipId(
          circleIdValue,
          uid,
        ),
      );

    const changed =
      await db.runTransaction(
        async (tx) => {
          const [
            circle,
            membership,
          ] = await Promise.all([
            tx.get(circleRef),
            tx.get(membershipRef),
          ]);

          if (
            !circle.exists ||
            !membership.exists
          ) {
            throw new HttpsError(
              'not-found',
              'Circle membership was not found.',
            );
          }

          if (
            membership.get('role') ===
              'owner' ||
            String(
              circle.get(
                'ownerUid',
              ) ?? '',
            ) === uid
          ) {
            throw new HttpsError(
              'failed-precondition',
              'The Circle owner cannot leave. Archive, delete, or transfer the Circle through its lifecycle controls.',
            );
          }

          if (
            membership.get(
              'status',
            ) !== 'active'
          ) {
            return false;
          }

          tx.update(
            membershipRef,
            {
              status: 'left',

              leftAt:
                FieldValue.serverTimestamp(),

              updatedAt:
                FieldValue.serverTimestamp(),
            },
          );

          return true;
        },
      );

    return {
      left: true,
      changed,
    };
  },
);

/**
 * Return only Circles and invitations
 * directly involving this user.
 */
export const listMyCircles = onCall(
  {
    enforceAppCheck: true,
    maxInstances: 20,
  },
  async (request) => {
    const db = getFirestore();
    const uid = requireUid(request.auth);

    await Promise.all([
      assertActiveCompliantMember(
        db,
        uid,
      ),

      consumeCircleRateLimit(
        uid,
        'list',
        120,
        60_000,
      ),
    ]);

    const [
      memberships,
      invitations,
    ] = await Promise.all([
      db
        .collection(
          'circle_memberships',
        )
        .where(
          'uid',
          '==',
          uid,
        )
        .limit(100)
        .get(),

      db
        .collection(
          'circle_invites',
        )
        .where(
          'inviteeUid',
          '==',
          uid,
        )
        .limit(100)
        .get(),
    ]);

    const activeMemberships =
      memberships.docs.filter(
        (doc) =>
          doc.get('status') ===
          'active',
      );

    const pendingInvites =
      invitations.docs.filter(
        (doc) =>
          doc.get('status') ===
          'pending',
      );

    const circleIds =
      new Set<string>();

    for (
      const membership
      of activeMemberships
    ) {
      const id = String(
        membership.get(
          'circleId',
        ) ?? '',
      );

      if (id) {
        circleIds.add(id);
      }
    }

    for (
      const invitation
      of pendingInvites
    ) {
      const id = String(
        invitation.get(
          'circleId',
        ) ?? '',
      );

      if (id) {
        circleIds.add(id);
      }
    }

    const refs = [...circleIds].map(
      (id) =>
        db.collection('circles').doc(id),
    );

    const circleDocs =
      refs.length > 0 ?
        await db.getAll(...refs) :
        [];

    const circlesById =
      new Map<
        string,
        FirebaseFirestore.DocumentSnapshot
      >();

    for (const circle of circleDocs) {
      if (
        circle.exists &&
        circle.get('status') ===
          'active'
      ) {
        circlesById.set(
          circle.id,
          circle,
        );
      }
    }

    const circleOutput =
      activeMemberships
        .map((membership) => {
          const circleIdValue =
            String(
              membership.get(
                'circleId',
              ) ?? '',
            );

          const circle =
            circlesById.get(
              circleIdValue,
            );

          if (!circle) {
            return null;
          }

          return {
            circleId:
              circle.id,

            name:
              String(
                circle.get(
                  'name',
                ) ?? '',
              ).slice(0, 60),

            ownerUid:
              String(
                circle.get(
                  'ownerUid',
                ) ?? '',
              ),

            role:
              String(
                membership.get(
                  'role',
                ) ?? 'member',
              ),

            status: 'active',
          };
        })
        .filter(
          (value) => value !== null,
        );

    const inviteOutput =
      pendingInvites
        .map((invitation) => {
          const circleIdValue =
            String(
              invitation.get(
                'circleId',
              ) ?? '',
            );

          const circle =
            circlesById.get(
              circleIdValue,
            );

          if (!circle) {
            return null;
          }

          return {
            inviteId:
              invitation.id,

            circleId:
              circle.id,

            circleName:
              String(
                circle.get(
                  'name',
                ) ?? '',
              ).slice(0, 60),

            inviterUid:
              String(
                invitation.get(
                  'inviterUid',
                ) ?? '',
              ),

            status: 'pending',
          };
        })
        .filter(
          (value) => value !== null,
        );

    return {
      circles: circleOutput,
      invites: inviteOutput,
    };
  },
);
