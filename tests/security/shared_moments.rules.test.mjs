import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, serverTimestamp, setDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const projectId = 'polycircle-shared-moments-rules-test';
let env;

before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {rules}});
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await Promise.all([
      setDoc(doc(db, 'users', 'alice'), {uid: 'alice', accountStatus: 'active'}),
      setDoc(doc(db, 'users', 'bob'), {uid: 'bob', accountStatus: 'active'}),
      setDoc(doc(db, 'conversations', 'alice_bob'), {
        participantUids: ['alice', 'bob'],
        active: true,
        createdAt: new Date(),
        lastMessageAt: new Date(),
      }),
      setDoc(doc(db, 'messages', 'server-created-moment'), {
        conversationId: 'alice_bob',
        senderUid: 'alice',
        text: 'First picnic',
        createdAt: new Date(),
        isDeleted: false,
        messageType: 'shared_moment',
        readBy: ['alice'],
        momentKind: 'note',
        momentTitle: 'First picnic',
        momentNote: '',
      }),
    ]);
  });
});

after(async () => env.cleanup());

test('active participants can read a backend-created shared moment', async () => {
  const db = env.authenticatedContext('bob').firestore();
  await assertSucceeds(getDoc(doc(db, 'messages', 'server-created-moment')));
});

test('clients cannot create a shared moment directly', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'messages', 'forged-moment'), {
    conversationId: 'alice_bob',
    senderUid: 'alice',
    text: 'Forged moment',
    createdAt: serverTimestamp(),
    isDeleted: false,
    messageType: 'shared_moment',
    readBy: ['alice'],
    momentKind: 'note',
    momentTitle: 'Forged moment',
    momentNote: '',
  }));
});

test('non-participants cannot read a backend-created shared moment', async () => {
  const db = env.authenticatedContext('mallory').firestore();
  await assertFails(getDoc(doc(db, 'messages', 'server-created-moment')));
});
