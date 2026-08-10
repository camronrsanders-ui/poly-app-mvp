import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, setDoc, updateDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const projectId = 'polycircle-user-account-rules-test';
let env;

const userDoc = (uid, overrides = {}) => ({
  uid,
  email: `${uid}@example.com`,
  createdAt: new Date(),
  onboardingComplete: false,
  lastActiveAt: new Date(),
  accountStatus: 'active',
  ...overrides,
});

const profileDoc = (uid) => ({
  uid,
  displayName: uid,
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
  createdAt: new Date(),
  updatedAt: new Date(),
});

async function adminSeed(entries) {
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

test('new account document must use the minimal trusted client schema', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  const mallory = env.authenticatedContext('mallory').firestore();
  await assertSucceeds(setDoc(doc(alice, 'users', 'alice'), userDoc('alice')));
  await assertFails(setDoc(doc(mallory, 'users', 'mallory'), userDoc('mallory', {
    role: 'admin',
  })));
});

test('new account cannot skip onboarding during bootstrap', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'users', 'alice'), userDoc('alice', {
    onboardingComplete: true,
  })));
});

test('onboarding cannot be marked complete until a profile exists', async () => {
  await adminSeed([['users', 'alice', userDoc('alice')]]);
  const db = env.authenticatedContext('alice').firestore();

  await assertFails(updateDoc(doc(db, 'users', 'alice'), {
    onboardingComplete: true,
    lastActiveAt: new Date(),
  }));

  await adminSeed([['profiles', 'alice', profileDoc('alice')]]);
  await assertSucceeds(updateDoc(doc(db, 'users', 'alice'), {
    onboardingComplete: true,
    lastActiveAt: new Date(),
  }));
});

test('client cannot rewrite account identity or moderation fields', async () => {
  await adminSeed([['users', 'alice', userDoc('alice')]]);
  const db = env.authenticatedContext('alice').firestore();

  await assertFails(updateDoc(doc(db, 'users', 'alice'), {email: 'other@example.com'}));
  await assertFails(updateDoc(doc(db, 'users', 'alice'), {accountStatus: 'banned'}));
  await assertFails(updateDoc(doc(db, 'users', 'alice'), {uid: 'bob'}));
  await assertFails(updateDoc(doc(db, 'users', 'alice'), {role: 'moderator'}));
});

test('active account can refresh only ordinary activity state', async () => {
  await adminSeed([['users', 'alice', userDoc('alice')]]);
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(updateDoc(doc(db, 'users', 'alice'), {
    lastActiveAt: new Date(),
  }));
});
