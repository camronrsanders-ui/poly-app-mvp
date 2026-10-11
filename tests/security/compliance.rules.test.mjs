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

test('legacy active account can read own account marker but cannot access member data until trusted approval', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', 'alice'), {
      uid: 'alice',
      accountStatus: 'active',
      // Deliberately omit approval and policy fields to model legacy accounts.
    });
    await setDoc(doc(db, 'profiles', 'alice'), {
      ...baseProfile('alice'),
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });

  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'users', 'alice')));
  await assertFails(getDoc(doc(db, 'profiles', 'alice')));
  await assertFails(setDoc(doc(db, 'relationship_cards', 'new-card'), {
    ownerUid: 'alice',
    label: 'Partner',
    connectionType: 'romantic',
    displayNameOptional: '',
    status: 'active',
    note: '',
    visibility: 'private',
    sortOrder: 0,
    isActive: true,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));

  await trustedApproveAdultAccess();
  await assertSucceeds(getDoc(doc(db, 'profiles', 'alice')));
});

test('partial or stale trusted compliance cannot unlock existing profile', async () => {
  for (const [index, approval] of [
    {adultAccessApproved: true},
    {
      adultAccessApproved: true,
      termsAcceptedVersion: '2026-08-alpha-v1',
    },
    {
      adultAccessApproved: true,
      termsAcceptedVersion: 'stale-terms',
      communityGuidelinesAcceptedVersion: '2026-08-v1',
    },
  ].entries()) {
    const uid = `legacy-${index}`;
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', uid), {
        uid,
        accountStatus: 'active',
        ...approval,
      });
      await setDoc(doc(db, 'profiles', uid), {
        ...baseProfile(uid),
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    });
    const db = env.authenticatedContext(uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', uid)));
    await assertFails(getDoc(doc(db, 'profiles', uid)));
  }
});
