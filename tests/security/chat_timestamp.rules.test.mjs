import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, serverTimestamp, setDoc, updateDoc, writeBatch} from 'firebase/firestore';

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
        lastMessageId: null,
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

test('chat accepts only an atomic message plus matching conversation activity update', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const batch = writeBatch(db);
  const messageRef = doc(db, 'messages', 'message-server-time');
  batch.set(messageRef, message(serverTimestamp()));
  batch.update(doc(db, 'conversations', 'alice_bob'), {
    lastMessageAt: serverTimestamp(),
    lastMessageId: messageRef.id,
  });
  await assertSucceeds(batch.commit());
});

test('standalone message create cannot bypass conversation activity binding', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(
    doc(db, 'messages', 'standalone-message'),
    message(serverTimestamp()),
  ));
});

test('standalone conversation activity bump cannot fake a message', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(updateDoc(doc(db, 'conversations', 'alice_bob'), {
    lastMessageAt: serverTimestamp(),
    lastMessageId: 'nonexistent-message',
  }));
});

test('chat rejects caller-forged timestamps even in a linked atomic batch', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const forged = new Date('2000-01-01T00:00:00.000Z');
  const batch = writeBatch(db);
  const messageRef = doc(db, 'messages', 'message-forged-time');
  batch.set(messageRef, message(forged));
  batch.update(doc(db, 'conversations', 'alice_bob'), {
    lastMessageAt: forged,
    lastMessageId: messageRef.id,
  });
  await assertFails(batch.commit());
});

test('conversation cannot point at a different message than the one being created', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const batch = writeBatch(db);
  const messageRef = doc(db, 'messages', 'message-a');
  batch.set(messageRef, message(serverTimestamp()));
  batch.update(doc(db, 'conversations', 'alice_bob'), {
    lastMessageAt: serverTimestamp(),
    lastMessageId: 'message-b',
  });
  await assertFails(batch.commit());
});

test('chat rejects extra client-controlled message fields', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const batch = writeBatch(db);
  const messageRef = doc(db, 'messages', 'message-extra-field');
  batch.set(messageRef, {
    ...message(serverTimestamp()),
    moderationApproved: true,
  });
  batch.update(doc(db, 'conversations', 'alice_bob'), {
    lastMessageAt: serverTimestamp(),
    lastMessageId: messageRef.id,
  });
  await assertFails(batch.commit());
});
