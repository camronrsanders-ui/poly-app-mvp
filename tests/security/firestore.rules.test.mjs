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
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const projectId = 'polycircle-security-test';
let env;

const baseProfile = (uid, visibility = 'public') => ({
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
  relationshipStructure: 'Solo poly',
  relationshipStatus: 'single',
  lookingForNote: '',
  profileVisibility: visibility,
  mapVisibility: 'matches_only',
  photoUrls: [],
  intentionTags: ['Friendship'],
  interests: [],
  createdAt: new Date(),
  updatedAt: new Date(),
});

async function adminSeed(seed) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [collection, id, data] of seed) {
      await setDoc(doc(db, collection, id), data);
    }
  });
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {rules},
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

test('unauthenticated user cannot read a public profile', async () => {
  await adminSeed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['profiles', 'alice', baseProfile('alice')],
  ]);
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'profiles', 'alice')));
});

test('profile owner can read own profile', async () => {
  await adminSeed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['profiles', 'alice', baseProfile('alice', 'hidden')],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'profiles', 'alice')));
});

test('unrelated user cannot update another profile', async () => {
  await adminSeed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['profiles', 'alice', baseProfile('alice')],
  ]);
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(updateDoc(doc(db, 'profiles', 'alice'), {bio: 'forged'}));
});

test('blocked user cannot directly read an otherwise public profile', async () => {
  await adminSeed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['profiles', 'alice', baseProfile('alice')],
    ['blocks', 'alice_bob', {blockerUid: 'alice', blockedUid: 'bob'}],
  ]);
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'profiles', 'alice')));
});

test('matches-only profile is unreadable without a match', async () => {
  await adminSeed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['profiles', 'alice', baseProfile('alice', 'matches_only')],
  ]);
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'profiles', 'alice')));
});

test('matches-only profile is readable by an active match', async () => {
  await adminSeed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['profiles', 'alice', baseProfile('alice', 'matches_only')],
    ['matches', 'alice_bob', {userAUid: 'alice', userBUid: 'bob', active: true}],
  ]);
  const db = env.authenticatedContext('bob').firestore();
  await assertSucceeds(getDoc(doc(db, 'profiles', 'alice')));
});

test('client cannot forge a match', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'matches', 'alice_bob'), {
    userAUid: 'alice',
    userBUid: 'bob',
    active: true,
    createdAt: new Date(),
  }));
});

test('client cannot create a conversation directly', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'conversations', 'alice_bob'), {
    participantUids: ['alice', 'bob'],
    active: true,
    createdAt: new Date(),
    lastMessageAt: new Date(),
  }));
});

test('client cannot read private-media metadata even when authenticated', async () => {
  await adminSeed([
    ['private_media', 'media1', {ownerUid: 'alice', status: 'active'}],
  ]);
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(alice, 'private_media', 'media1')));
  await assertFails(getDoc(doc(bob, 'private_media', 'media1')));
});

test('blocked pair cannot read an existing conversation or messages', async () => {
  await adminSeed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['conversations', 'alice_bob', {
      participantUids: ['alice', 'bob'],
      active: true,
      createdAt: new Date(),
      lastMessageAt: new Date(),
    }],
    ['messages', 'm1', {
      conversationId: 'alice_bob',
      senderUid: 'alice',
      text: 'hello',
      createdAt: new Date(),
      isDeleted: false,
      messageType: 'text',
      readBy: ['alice'],
    }],
    ['blocks', 'alice_bob', {blockerUid: 'alice', blockedUid: 'bob'}],
  ]);
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'conversations', 'alice_bob')));
  await assertFails(getDoc(doc(db, 'messages', 'm1')));
});
