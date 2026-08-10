import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, serverTimestamp, setDoc, updateDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'polycircle-circle-privacy-test',
    firestore: {rules},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

async function seed(entries) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [collection, id, data] of entries) {
      await setDoc(doc(db, collection, id), data);
    }
  });
}

const activeUser = (uid) => ({uid, accountStatus: 'active'});
const card = (ownerUid, visibility = 'public') => ({
  ownerUid,
  label: 'Partner',
  connectionType: 'romantic',
  displayNameOptional: 'Private Name',
  status: 'active',
  note: 'Potentially identifying free-text note',
  visibility,
  sortOrder: 0,
  isActive: true,
  createdAt: new Date(),
  updatedAt: new Date(),
});

const newCard = (ownerUid, overrides = {}) => ({
  ...card(ownerUid),
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...overrides,
});

test('active Circle owner can directly read their own full card', async () => {
  await seed([
    ['users', 'alice', activeUser('alice')],
    ['relationship_cards', 'card1', card('alice')],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'relationship_cards', 'card1')));
});

test('unrelated user cannot directly read a public Circle card', async () => {
  await seed([
    ['users', 'alice', activeUser('alice')],
    ['users', 'bob', activeUser('bob')],
    ['relationship_cards', 'card1', card('alice', 'public')],
  ]);
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'relationship_cards', 'card1')));
});

test('active match still cannot directly read the owners full Circle card', async () => {
  await seed([
    ['users', 'alice', activeUser('alice')],
    ['users', 'bob', activeUser('bob')],
    ['relationship_cards', 'card1', card('alice', 'matches_only')],
    ['matches', 'alice_bob', {userAUid: 'alice', userBUid: 'bob', active: true}],
  ]);
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'relationship_cards', 'card1')));
});

test('Circle owner cannot add unknown privileged fields to a card', async () => {
  await seed([
    ['users', 'alice', activeUser('alice')],
    ['relationship_cards', 'card1', card('alice')],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(updateDoc(doc(db, 'relationship_cards', 'card1'), {
    moderationApproved: true,
    updatedAt: serverTimestamp(),
  }));
});

test('Circle create and update require server-authoritative timestamps', async () => {
  await seed([['users', 'alice', activeUser('alice')]]);
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(db, 'relationship_cards', 'server-time'), newCard('alice')));
  await assertFails(setDoc(doc(db, 'relationship_cards', 'forged-time'), newCard('alice', {
    createdAt: new Date('2000-01-01T00:00:00.000Z'),
    updatedAt: new Date('2000-01-01T00:00:00.000Z'),
  })));

  await seed([['relationship_cards', 'existing', card('alice')]]);
  await assertSucceeds(updateDoc(doc(db, 'relationship_cards', 'existing'), {
    note: 'Updated safely',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'relationship_cards', 'existing'), {
    note: 'Forged clock',
    updatedAt: new Date('2000-01-01T00:00:00.000Z'),
  }));
});

test('inactive Circle owner cannot read or mutate a card', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'suspended'}],
    ['relationship_cards', 'card1', card('alice')],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(getDoc(doc(db, 'relationship_cards', 'card1')));
  await assertFails(updateDoc(doc(db, 'relationship_cards', 'card1'), {
    note: 'should fail',
    updatedAt: serverTimestamp(),
  }));
});
