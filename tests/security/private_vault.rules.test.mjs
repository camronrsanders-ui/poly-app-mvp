import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {assertFails, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {deleteDoc, doc, getDoc, setDoc, updateDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const projectId = 'polycircle-private-vault-rules-test';
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

test('clients cannot read or manipulate private-media grants', async () => {
  await seed([['private_media_grants', 'media1_bob', {
    mediaId: 'media1', ownerUid: 'alice', recipientUid: 'bob', active: true,
  }]]);
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(alice, 'private_media_grants', 'media1_bob')));
  await assertFails(getDoc(doc(bob, 'private_media_grants', 'media1_bob')));
  await assertFails(updateDoc(doc(alice, 'private_media_grants', 'media1_bob'), {active: false}));
  await assertFails(deleteDoc(doc(alice, 'private_media_grants', 'media1_bob')));
});

test('clients cannot create private-media requests directly', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(alice, 'private_media_requests', 'alice_bob'), {
    requestId: 'alice_bob', requesterUid: 'alice', recipientUid: 'bob', status: 'pending',
  }));
});

test('do-not-ask preferences are completely backend-only', async () => {
  await seed([['private_media_request_preferences', 'bob_alice', {
    recipientUid: 'bob', requesterUid: 'alice', doNotAskAgain: true,
  }]]);
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(alice, 'private_media_request_preferences', 'bob_alice')));
  await assertFails(getDoc(doc(bob, 'private_media_request_preferences', 'bob_alice')));
  await assertFails(updateDoc(doc(bob, 'private_media_request_preferences', 'bob_alice'), {doNotAskAgain: false}));
});
