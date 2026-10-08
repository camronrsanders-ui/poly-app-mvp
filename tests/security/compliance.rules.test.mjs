import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const projectId = 'polycircle-compliance-test';
let env;

const baseProfile = (uid) => ({
  uid,
  displayName: 'Alice',
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
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

async function createPendingAdultAccount(db, uid = 'alice') {
  await assertSucceeds(setDoc(doc(db, 'users', uid), {
    uid,
    email: `${uid}@example.com`,
    createdAt: serverTimestamp(),
    onboardingComplete: false,
    lastActiveAt: serverTimestamp(),
    accountStatus: 'active',
    adultAccessApproved: false,
  }));
}

async function trustedApproveAdultAccess(uid = 'alice') {
  // Admin/rules-disabled writes represent the trusted callable's Admin SDK
  // mutation. The client must never be able to perform this transition itself.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'users', uid), {
      adultAccessApproved: true,
      termsAcceptedVersion: '2026-08-alpha-v1',
      communityGuidelinesAcceptedVersion: '2026-08-v1',
      ageAssuranceMethod: 'play_age_signals',
      ageSignalStatus: 'adult:shared_verified',
      ageAssuranceCheckedAt: new Date(),
      ugcPolicyAcceptedAt: new Date(),
      lastActiveAt: new Date(),
    });
  });
}

before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {rules}});
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

test('new account cannot create member profile before adult compliance acceptance', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await createPendingAdultAccount(db);
  await assertFails(setDoc(doc(db, 'profiles', 'alice'), baseProfile('alice')));
});

test('trusted current adult and UGC policy acceptance unlocks profile creation', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await createPendingAdultAccount(db);
  await trustedApproveAdultAccess();

  const account = await assertSucceeds(getDoc(doc(db, 'users', 'alice')));
  if (account.data()?.adultAccessApproved !== true) {
    throw new Error('Trusted approval fixture did not establish adult access.');
  }
  await assertSucceeds(setDoc(doc(db, 'profiles', 'alice'), baseProfile('alice')));
});

test('client cannot self-approve adult access even with a complete current policy record', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await createPendingAdultAccount(db);

  await assertFails(updateDoc(doc(db, 'users', 'alice'), {
    adultAccessApproved: true,
    termsAcceptedVersion: '2026-08-alpha-v1',
    communityGuidelinesAcceptedVersion: '2026-08-v1',
    ageAssuranceMethod: 'play_age_signals',
    ageSignalStatus: 'adult:shared_verified',
    ageAssuranceCheckedAt: serverTimestamp(),
    ugcPolicyAcceptedAt: serverTimestamp(),
    lastActiveAt: serverTimestamp(),
  }));

  await assertFails(updateDoc(doc(db, 'users', 'alice'), {
    adultAccessApproved: true,
    lastActiveAt: serverTimestamp(),
  }));
});
