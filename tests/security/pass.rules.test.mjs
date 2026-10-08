import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'polycircle-pass-rules-test',
    firestore: {rules},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

async function seedPass() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'profile_passes', 'alice_bob'), {
      passId: 'alice_bob',
      fromUid: 'alice',
      toUid: 'bob',
      createdAt: new Date(),
    });
  });
}

test('pass owner cannot directly read backend-owned pass state', async () => {
  await seedPass();
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(getDoc(doc(db, 'profile_passes', 'alice_bob')));
});

test('passed user cannot discover that another member passed them', async () => {
  await seedPass();
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'profile_passes', 'alice_bob')));
});

test('client cannot forge, change, or delete pass state', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'profile_passes', 'alice_bob'), {
    passId: 'alice_bob',
    fromUid: 'alice',
    toUid: 'bob',
    createdAt: new Date(),
  }));

  await seedPass();
  await assertFails(updateDoc(doc(db, 'profile_passes', 'alice_bob'), {toUid: 'carol'}));
  await assertFails(deleteDoc(doc(db, 'profile_passes', 'alice_bob')));
});
