// Circle lifecycle decisions for archive / restore (Step 2, Item 3).
//
// The callables in circle_membership.ts own all Firestore access; this
// module owns the pure decisions that must stay testable without a
// database: who may archive or restore a Circle, and what each current
// status means for the request. The owner check is deliberately the
// same double check leaveCircle has always used - the membership role
// AND the Circle's ownerUid must both name the caller - so no single
// corrupted document can hand the lifecycle to the wrong person.
//
// Archiving is the owner's exit: it deletes nothing, freezes invites,
// and is fully reversible through unarchive. A request against a
// Circle already in the target state is a no-op, not an error, so a
// retried tap can never strand the owner on an error screen.

export interface CircleLifecycleFacts {
  circleExists: boolean;
  membershipExists: boolean;
  membershipRole: unknown;
  circleOwnerUid: unknown;
  circleStatus: unknown;
  uid: string;
}

export type CircleLifecycleVerdict =
  | {action: 'proceed'}
  | {action: 'noop'}
  | {
      action: 'deny';
      code:
        | 'not-found'
        | 'permission-denied'
        | 'failed-precondition';
      message: string;
    };

function lifecycleOwnerDenial(
  facts: CircleLifecycleFacts,
  message: string,
): CircleLifecycleVerdict | null {
  if (!facts.circleExists || !facts.membershipExists) {
    return {
      action: 'deny',
      code: 'not-found',
      message: 'Circle membership was not found.',
    };
  }

  if (
    String(facts.membershipRole ?? '') !== 'owner' ||
    String(facts.circleOwnerUid ?? '') !== facts.uid
  ) {
    return {
      action: 'deny',
      code: 'permission-denied',
      message,
    };
  }

  return null;
}

export function evaluateArchiveCircle(
  facts: CircleLifecycleFacts,
): CircleLifecycleVerdict {
  const denial = lifecycleOwnerDenial(
    facts,
    'Only the Circle owner can archive this Circle.',
  );

  if (denial) {
    return denial;
  }

  if (facts.circleStatus === 'archived') {
    return {action: 'noop'};
  }

  if (facts.circleStatus !== 'active') {
    return {
      action: 'deny',
      code: 'failed-precondition',
      message: 'This Circle is not active.',
    };
  }

  return {action: 'proceed'};
}

export function evaluateUnarchiveCircle(
  facts: CircleLifecycleFacts,
): CircleLifecycleVerdict {
  const denial = lifecycleOwnerDenial(
    facts,
    'Only the Circle owner can restore this Circle.',
  );

  if (denial) {
    return denial;
  }

  if (facts.circleStatus === 'active') {
    return {action: 'noop'};
  }

  if (facts.circleStatus !== 'archived') {
    return {
      action: 'deny',
      code: 'failed-precondition',
      message: 'This Circle is not archived.',
    };
  }

  return {action: 'proceed'};
}

// Archiving expires the Circle's pending invitations in the same
// write: accept already refuses non-active Circles, but an invite
// left 'pending' forever would make every list that reads it
// dishonest, and would silently resurrect if the Circle is restored.
export function shouldExpireInviteOnArchive(
  inviteStatus: unknown,
): boolean {
  return inviteStatus === 'pending';
}

// The archived list in listMyCircles is owner-only: a Circle appears
// there only when it is archived AND the caller is its owner.
// Members never receive another member's archived Circles.
export function isOwnerArchivedCircle(
  circleStatus: unknown,
  circleOwnerUid: unknown,
  uid: string,
): boolean {
  return (
    circleStatus === 'archived' &&
    String(circleOwnerUid ?? '') === uid
  );
}
