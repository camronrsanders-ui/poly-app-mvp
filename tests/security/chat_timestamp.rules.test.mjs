import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, serverTimestamp, setDoc, updateDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const projectId = 'polycircle-chat-timestamp-rules-test';
let env;

async function seedActiveConversation() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await Promise.all([
      setDoc(doc(db, 'users', 'alice'), {uid: 'alice', accountStatus: 'active'}),
      setDoc(doc(db, 'users', 'bob'), {uid: 'bob', accountStatus: 'active'}),
      setDoc(doc(db, 'conversations', 'alice_bob'), {
        conversationId: 'alice_bob',
        participantUids: ['alice', 'bob'],
        active: true,
        createdAt: new Date(Date.now() - 60_000),
        lastMessageAt: new Date(Date.now() - 30_000),
      }),
    ]);
  });
}

function message(createdAt) {
  return {
    conversationId: 'alice_bob',
    senderUid: 'alice',
    text: 'hello',
    createdAt,
    isDeleted: false,
    messageType: 'text',
    readBy: ['alice'],
  };
}

before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {rules}});
});

beforeEach(async () => {
  await env.clearFirestore();
  await seedActiveConversation();
});

after(async () => env.cleanup());

test('chat accepts server-generated timestamps for message and conversation activity', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(
    doc(db, 'messages', 'message-server-time'),
    message(serverTimestamp()),
  ));
  await assertSucceeds(updateDoc(doc(db, 'conversations', 'alice_bob'), {
    lastMessageAt: serverTimestamp(),
  }));
});

test('chat rejects caller-forged message and conversation timestamps', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const forged = new Date('2000-01-01T00:00:00.000Z');

  await assertFails(setDoc(
    doc(db, 'messages', 'message-forged-time'),
    message(forged),
  ));
  await assertFails(updateDoc(doc(db, 'conversations', 'alice_bob'), {
    lastMessageAt: forged,
  }));
});

test('chat rejects extra client-controlled message fields', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'messages', 'message-extra-field'), {
    ...message(serverTimestamp()),
    moderationApproved: true,
  }));
});
