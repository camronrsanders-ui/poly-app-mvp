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
const projectId = 'polycircle-user-account-rules-test';
let env;

const userDoc = (uid, overrides = {}) => ({
  uid,
  email: `${uid}@example.com`,
  createdAt: serverTimestamp(),
  onboardingComplete: false,
  lastActiveAt: serverTimestamp(),
  accountStatus: 'active',
  adultAccessApproved: false,
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

test('new account rejects caller-forged creation and activity timestamps', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'users', 'alice'), userDoc('alice', {
    createdAt: new Date('2000-01-01T00:00:00.000Z'),
    lastActiveAt: new Date('2000-01-01T00:00:00.000Z'),
  })));
});

test('new account cannot skip onboarding during bootstrap', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'users', 'alice'), userDoc('alice', {
    onboardingComplete: true,
  })));
});

test('explicit adult approval still requires current policy versions for member data access', async () => {
  const currentCompliance = {
    accountStatus: 'active',
    adultAccessApproved: true,
    termsAcceptedVersion: '2026-08-alpha-v1',
    communityGuidelinesAcceptedVersion: '2026-08-v1',
  };
  await adminSeed([
    ['users', 'alice', {uid: 'alice', ...currentCompliance}],
    ['users', 'bob', {
      uid: 'bob',
      ...currentCompliance,
      termsAcceptedVersion: 'stale-terms',
    }],
    ['profiles', 'alice', profileDoc('alice')],
    ['profiles', 'bob', profileDoc('bob')],
  ]);

  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertSucceeds(getDoc(doc(alice, 'profiles', 'alice')));
  await assertFails(getDoc(doc(bob, 'profiles', 'bob')));
});

test('onboarding cannot be marked complete until a profile exists', async () => {
  await adminSeed([['users', 'alice', {
    uid: 'alice',
    email: 'alice@example.com',
    createdAt: new Date(),
    onboardingComplete: false,
    lastActiveAt: new Date(),
    accountStatus: 'active',
  }]]);
  const db = env.authenticatedContext('alice').firestore();

  await assertFails(updateDoc(doc(db, 'users', 'alice'), {
    onboardingComplete: true,
    lastActiveAt: serverTimestamp(),
  }));

  await adminSeed([['profiles', 'alice', profileDoc('alice')]]);
  await assertSucceeds(updateDoc(doc(db, 'users', 'alice'), {
    onboardingComplete: true,
    lastActiveAt: serverTimestamp(),
  }));
});

test('client cannot rewrite account identity or moderation fields', async () => {
  await adminSeed([['users', 'alice', {
    uid: 'alice',
    email: 'alice@example.com',
    createdAt: new Date(),
    onboardingComplete: false,
    lastActiveAt: new Date(),
    accountStatus: 'active',
  }]]);
  const db = env.authenticatedContext('alice').firestore();

  await assertFails(updateDoc(doc(db, 'users', 'alice'), {email: 'other@example.com', lastActiveAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(db, 'users', 'alice'), {accountStatus: 'banned', lastActiveAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(db, 'users', 'alice'), {uid: 'bob', lastActiveAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(db, 'users', 'alice'), {role: 'moderator', lastActiveAt: serverTimestamp()}));
});

test('active account can refresh activity only with server time', async () => {
  await adminSeed([['users', 'alice', {
    uid: 'alice',
    email: 'alice@example.com',
    createdAt: new Date(),
    onboardingComplete: false,
    lastActiveAt: new Date(),
    accountStatus: 'active',
  }]]);
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(updateDoc(doc(db, 'users', 'alice'), {
    lastActiveAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'users', 'alice'), {
    lastActiveAt: new Date('2000-01-01T00:00:00.000Z'),
  }));
});
