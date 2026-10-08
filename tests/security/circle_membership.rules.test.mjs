import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {
  after,
  before,
  beforeEach,
  test,
} from 'node:test';

import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  doc,
  getDoc,
  setDoc,
} from 'firebase/firestore';

const __dirname = path.dirname(
  fileURLToPath(import.meta.url),
);

const rules = fs.readFileSync(
  path.join(
    __dirname,
    '../../firestore.rules',
  ),
  'utf8',
);

const projectId =
  'polycircle-circle-membership-test';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {rules},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

test(
  'Circle lifecycle collections are not directly readable by clients',
  async () => {
    await env.withSecurityRulesDisabled(
      async (context) => {
        const db = context.firestore();

        await setDoc(
          doc(db, 'circles', 'circle-1'),
          {
            ownerUid: 'alice',
            name: 'House',
            status: 'active',
          },
        );

        await setDoc(
          doc(
            db,
            'circle_memberships',
            'circle-1_alice',
          ),
          {
            circleId: 'circle-1',
            uid: 'alice',
            role: 'owner',
            status: 'active',
          },
        );

        await setDoc(
          doc(
            db,
            'circle_invites',
            'circle-1_bob',
          ),
          {
            circleId: 'circle-1',
            inviterUid: 'alice',
            inviteeUid: 'bob',
            status: 'pending',
          },
        );
      },
    );

    const db =
      env
        .authenticatedContext('alice')
        .firestore();

    await assertFails(
      getDoc(
        doc(
          db,
          'circles',
          'circle-1',
        ),
      ),
    );

    await assertFails(
      getDoc(
        doc(
          db,
          'circle_memberships',
          'circle-1_alice',
        ),
      ),
    );

    await assertFails(
      getDoc(
        doc(
          db,
          'circle_invites',
          'circle-1_bob',
        ),
      ),
    );
  },
);

test(
  'clients cannot forge Circle membership or invitations',
  async () => {
    const db =
      env
        .authenticatedContext('alice')
        .firestore();

    await assertFails(
      setDoc(
        doc(
          db,
          'circle_memberships',
          'circle-1_alice',
        ),
        {
          circleId: 'circle-1',
          uid: 'alice',
          role: 'owner',
          status: 'active',
        },
      ),
    );

    await assertFails(
      setDoc(
        doc(
          db,
          'circle_invites',
          'circle-1_bob',
        ),
        {
          circleId: 'circle-1',
          inviterUid: 'alice',
          inviteeUid: 'bob',
          status: 'pending',
        },
      ),
    );

    await assertFails(
      setDoc(
        doc(
          db,
          'circles',
          'circle-1',
        ),
        {
          ownerUid: 'alice',
          name: 'Fake Circle',
          status: 'active',
        },
      ),
    );
  },
);
