import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {collection, doc, getDoc, getDocs, orderBy, query, setDoc, updateDoc, where} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const projectId = 'polycircle-conversation-lifecycle-test';
let env;

async function seed(entries) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [collectionName, id, data] of entries) {
      await setDoc(doc(db, collectionName, id), data);
    }
  });
}

before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {rules}});
});

beforeEach(async () => env.clearFirestore());
after(async () => env.cleanup());

test('participant may read a known active conversation but cannot list the conversation collection', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['conversations', 'alice_bob', {
      conversationId: 'alice_bob',
      participantUids: ['alice', 'bob'],
      active: true,
      createdAt: new Date(),
      lastMessageAt: new Date(),
    }],
  ]);

  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'conversations', 'alice_bob')));
  await assertFails(getDocs(query(
    collection(db, 'conversations'),
    where('participantUids', 'array-contains', 'alice'),
    where('active', '==', true),
  )));
});

test('active participant can query messages for one known conversation while a nonparticipant cannot', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['users', 'carol', {uid: 'carol', accountStatus: 'active'}],
    ['conversations', 'alice_bob', {
      conversationId: 'alice_bob',
      participantUids: ['alice', 'bob'],
      active: true,
      createdAt: new Date(Date.now() - 10_000),
      lastMessageAt: new Date(),
    }],
    ['messages', 'message-1', {
      conversationId: 'alice_bob',
      senderUid: 'alice',
      text: 'hello',
      createdAt: new Date(Date.now() - 5_000),
      isDeleted: false,
      messageType: 'text',
      readBy: ['alice'],
    }],
    ['messages', 'message-2', {
      conversationId: 'alice_bob',
      senderUid: 'bob',
      text: 'hi',
      createdAt: new Date(),
      isDeleted: false,
      messageType: 'text',
      readBy: ['bob'],
    }],
  ]);

  const aliceDb = env.authenticatedContext('alice').firestore();
  const carolDb = env.authenticatedContext('carol').firestore();
  const aliceQuery = query(
    collection(aliceDb, 'messages'),
    where('conversationId', '==', 'alice_bob'),
    orderBy('createdAt'),
  );
  const carolQuery = query(
    collection(carolDb, 'messages'),
    where('conversationId', '==', 'alice_bob'),
    orderBy('createdAt'),
  );

  await assertSucceeds(getDocs(aliceQuery));
  await assertFails(getDocs(carolQuery));
});

test('blocked participant cannot query existing chat history', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['conversations', 'alice_bob', {
      conversationId: 'alice_bob',
      participantUids: ['alice', 'bob'],
      active: true,
      createdAt: new Date(Date.now() - 10_000),
      lastMessageAt: new Date(),
    }],
    ['messages', 'message-1', {
      conversationId: 'alice_bob',
      senderUid: 'alice',
      text: 'history',
      createdAt: new Date(),
      isDeleted: false,
      messageType: 'text',
      readBy: ['alice'],
    }],
    ['blocks', 'alice_bob', {blockerUid: 'alice', blockedUid: 'bob'}],
  ]);

  const aliceDb = env.authenticatedContext('alice').firestore();
  const bobDb = env.authenticatedContext('bob').firestore();
  for (const db of [aliceDb, bobDb]) {
    await assertFails(getDocs(query(
      collection(db, 'messages'),
      where('conversationId', '==', 'alice_bob'),
      orderBy('createdAt'),
    )));
  }
});

test('participant cannot reactivate an inactive conversation', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['conversations', 'alice_bob', {
      conversationId: 'alice_bob',
      participantUids: ['alice', 'bob'],
      active: false,
      createdAt: new Date(),
      lastMessageAt: new Date(),
    }],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(updateDoc(doc(db, 'conversations', 'alice_bob'), {
    active: true,
    lastMessageAt: new Date(),
  }));
});

test('participant cannot send a new message to an inactive conversation', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['conversations', 'alice_bob', {
      conversationId: 'alice_bob',
      participantUids: ['alice', 'bob'],
      active: false,
      createdAt: new Date(),
      lastMessageAt: new Date(),
    }],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'messages', 'new-message'), {
    conversationId: 'alice_bob',
    senderUid: 'alice',
    text: 'should not send',
    createdAt: new Date(),
    isDeleted: false,
    messageType: 'text',
    readBy: ['alice'],
  }));
});

test('participant cannot read conversation metadata after the connection ends', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['conversations', 'alice_bob', {
      conversationId: 'alice_bob',
      participantUids: ['alice', 'bob'],
      active: false,
      createdAt: new Date(),
      lastMessageAt: new Date(),
      endedReason: 'unmatched',
    }],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(getDoc(doc(db, 'conversations', 'alice_bob')));
});

test('participant cannot read old messages after the connection ends', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['conversations', 'alice_bob', {
      conversationId: 'alice_bob',
      participantUids: ['alice', 'bob'],
      active: false,
      createdAt: new Date(),
      lastMessageAt: new Date(),
      endedReason: 'unmatched',
    }],
    ['messages', 'old-message', {
      conversationId: 'alice_bob',
      senderUid: 'alice',
      text: 'history',
      createdAt: new Date(),
      isDeleted: false,
      messageType: 'text',
      readBy: ['alice'],
    }],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(getDoc(doc(db, 'messages', 'old-message')));
  await assertFails(updateDoc(doc(db, 'messages', 'old-message'), {readBy: ['alice', 'bob']}));
});
