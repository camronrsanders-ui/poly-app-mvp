import {approvedAccount} from './approved_account_fixture.mjs';
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

const activeUser = (uid) => approvedAccount(uid);
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

test('Circle create and update reject severe UGC at the Firestore boundary', async () => {
  await seed([['users', 'alice', activeUser('alice')]]);
  const db = env.authenticatedContext('alice').firestore();

  await assertFails(setDoc(doc(db, 'relationship_cards', 'threat'), newCard('alice', {
    note: 'I will hurt you',
  })));
  await assertFails(setDoc(doc(db, 'relationship_cards', 'minor-solicitation'), newCard('alice', {
    note: 'Seeking an underage kid',
  })));
});

test('Circle create and update require server-authoritative timestamps', async () => {
  await seed([['users', 'alice', activeUser('alice')]]);
  const db = env.authenticatedContext('alice').firestore();
  // The successful create is unnamed: a named card must be private now
  // (H-10), and this test is about timestamps, not exposure.
  await assertSucceeds(setDoc(doc(db, 'relationship_cards', 'server-time'), newCard('alice', {
    displayNameOptional: '',
  })));
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

test('Circle create rejects a named card at any non-private visibility', async () => {
  await seed([['users', 'alice', activeUser('alice')]]);
  const db = env.authenticatedContext('alice').firestore();

  // newCard defaults to a named, public card: a unilateral public
  // claim about a named person (H-10).
  await assertFails(setDoc(doc(db, 'relationship_cards', 'named-public'), newCard('alice')));
  await assertFails(setDoc(doc(db, 'relationship_cards', 'named-matches'), newCard('alice', {
    visibility: 'matches_only',
  })));
  await assertFails(setDoc(doc(db, 'relationship_cards', 'named-unnamed'), newCard('alice', {
    visibility: 'unnamed_public',
  })));
});

test('Circle create accepts a named private card and an unnamed public card', async () => {
  await seed([['users', 'alice', activeUser('alice')]]);
  const db = env.authenticatedContext('alice').firestore();

  await assertSucceeds(setDoc(doc(db, 'relationship_cards', 'named-private'), newCard('alice', {
    visibility: 'private',
  })));
  await assertSucceeds(setDoc(doc(db, 'relationship_cards', 'unnamed-public'), newCard('alice', {
    displayNameOptional: '',
  })));
});

test('Circle update cannot newly expose a named card', async () => {
  await seed([
    ['users', 'alice', activeUser('alice')],
    ['relationship_cards', 'named-private', card('alice', 'private')],
    ['relationship_cards', 'unnamed-public', {...card('alice'), displayNameOptional: ''}],
  ]);
  const db = env.authenticatedContext('alice').firestore();

  // Flipping a named card from private to public is a new exposure.
  await assertFails(updateDoc(doc(db, 'relationship_cards', 'named-private'), {
    visibility: 'public',
    updatedAt: serverTimestamp(),
  }));
  // Adding a name to an already-public card is a new exposure.
  await assertFails(updateDoc(doc(db, 'relationship_cards', 'unnamed-public'), {
    displayNameOptional: 'New Name',
    updatedAt: serverTimestamp(),
  }));
});

test('pre-existing named public cards stay editable without new exposure', async () => {
  // Grandfathering (H-10): the card fixture is named and public, as
  // written before the interim rule (seeded here with rules disabled).
  // Rules validate the full resulting document on every update, so the
  // write gate is diff-aware: updates that touch neither the name nor
  // the visibility keep working, and updates that end the exposure
  // always work.
  await seed([
    ['users', 'alice', activeUser('alice')],
    ['relationship_cards', 'legacy', card('alice')],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  const legacy = doc(db, 'relationship_cards', 'legacy');

  await assertSucceeds(updateDoc(legacy, {
    sortOrder: 5,
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(legacy, {
    isActive: false,
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(updateDoc(legacy, {
    note: 'Edited safely',
    updatedAt: serverTimestamp(),
  }));
  // Renaming a still-public card publishes a new claim: rejected.
  await assertFails(updateDoc(legacy, {
    displayNameOptional: 'Different Name',
    updatedAt: serverTimestamp(),
  }));
  // Ending the exposure is always allowed.
  await assertSucceeds(updateDoc(legacy, {
    visibility: 'private',
    updatedAt: serverTimestamp(),
  }));
});

test('clearing the name lets a grandfathered card stay public', async () => {
  await seed([
    ['users', 'alice', activeUser('alice')],
    ['relationship_cards', 'legacy', card('alice')],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(updateDoc(doc(db, 'relationship_cards', 'legacy'), {
    displayNameOptional: '',
    updatedAt: serverTimestamp(),
  }));
});
