import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {deleteDoc, doc, serverTimestamp, setDoc, updateDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
let env;

const profile = (uid, timestamps = {createdAt: serverTimestamp(), updatedAt: serverTimestamp()}) => ({
  uid,
  displayName: 'Alex',
  age: 30,
  city: 'Boston',
  region: 'MA',
  bio: '',
  headline: '',
  genderIdentity: 'self-described',
  pronouns: 'they/them',
  orientation: 'self-described',
  customIdentityTags: [],
  relationshipStructure: 'Solo poly',
  relationshipStatus: 'single',
  partnered: false,
  openToConnections: true,
  intentionTags: ['Friendship'],
  interests: [],
  lookingForNote: '',
  ageMin: 18,
  ageMax: 99,
  distanceRadius: 50,
  preferredStructures: [],
  preferredIntentions: [],
  profileVisibility: 'public',
  mapVisibility: 'matches_only',
  ...timestamps,
});

async function seed(entries) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [collectionName, id, data] of entries) {
      await setDoc(doc(db, collectionName, id), data);
    }
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'polycircle-profile-timestamp-test',
    firestore: {rules},
  });
});

beforeEach(async () => env.clearFirestore());
after(async () => env.cleanup());

test('active owner can create profile only with server timestamps', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
  ]);
  const aliceDb = env.authenticatedContext('alice').firestore();
  const bobDb = env.authenticatedContext('bob').firestore();

  await assertSucceeds(setDoc(doc(aliceDb, 'profiles', 'alice'), profile('alice')));

  const forged = new Date('2000-01-01T00:00:00.000Z');
  await assertFails(setDoc(doc(bobDb, 'profiles', 'bob'), profile('bob', {
    createdAt: forged,
    updatedAt: forged,
  })));
});

test('profile write rejects severe UGC at the Firestore boundary', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
  ]);
  const db = env.authenticatedContext('alice').firestore();

  await assertFails(setDoc(doc(db, 'profiles', 'alice'), {
    ...profile('alice'),
    bio: 'I am going to hurt you',
  }));

  await assertFails(setDoc(doc(db, 'profiles', 'alice'), {
    ...profile('alice'),
    lookingForNote: 'Looking for an underage kid to meet',
  }));
});

test('profile update preserves creation time and requires server updatedAt', async () => {
  const createdAt = new Date('2026-01-01T00:00:00.000Z');
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['profiles', 'alice', profile('alice', {createdAt, updatedAt: new Date()})],
  ]);
  const db = env.authenticatedContext('alice').firestore();

  await assertSucceeds(updateDoc(doc(db, 'profiles', 'alice'), {
    bio: 'Updated',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'profiles', 'alice'), {
    bio: 'Forged update time',
    updatedAt: new Date('2000-01-01T00:00:00.000Z'),
  }));
  await assertFails(updateDoc(doc(db, 'profiles', 'alice'), {
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
});

test('active client cannot directly delete the profile and orphan account state', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['profiles', 'alice', profile('alice', {createdAt: new Date(), updatedAt: new Date()})],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(deleteDoc(doc(db, 'profiles', 'alice')));
});
