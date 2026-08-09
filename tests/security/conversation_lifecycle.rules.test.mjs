import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {assertFails, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, setDoc, updateDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const projectId = 'polycircle-conversation-lifecycle-test';
let env;

async function seed(entries) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [collection, id, data] of entries) {
      await setDoc(doc(db, collection, id), data);
    }
  });
}

before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {rules}});
});

beforeEach(async () => env.clearFirestore());
after(async () => env.cleanup());

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
