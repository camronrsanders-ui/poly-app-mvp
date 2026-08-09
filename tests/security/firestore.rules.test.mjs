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
  profileVisibility: visibility,
  mapVisibility: 'matches_only',
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

test('user cannot promote or alter their own moderation status', async () => {
  await adminSeed([
    ['users', 'alice', {
      uid: 'alice',
      email: 'alice@example.com',
      accountStatus: 'active',
      createdAt: new Date(),
      onboardingComplete: true,
      lastActiveAt: new Date(),
    }],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(updateDoc(doc(db, 'users', 'alice'), {accountStatus: 'banned'}));
});

test('client cannot create an underage profile', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'profiles', 'alice'), {
    ...baseProfile('alice'),
    age: 17,
  }));
});

test('profile owner cannot change uid ownership field', async () => {
  await adminSeed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['profiles', 'alice', baseProfile('alice')],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(updateDoc(doc(db, 'profiles', 'alice'), {uid: 'bob'}));
});

test('client cannot store permanent profile photo URLs', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'profiles', 'alice'), {
    ...baseProfile('alice'),
    photoUrls: ['https://example.invalid/permanent-photo.jpg'],
  }));
  await assertFails(setDoc(doc(db, 'profiles', 'alice'), {
    ...baseProfile('alice'),
    avatarUrl: 'https://example.invalid/avatar.jpg',
  }));
});

test('profile owner cannot add unknown privileged fields', async () => {
  await adminSeed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['profiles', 'alice', baseProfile('alice')],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(updateDoc(doc(db, 'profiles', 'alice'), {
    moderationApproved: true,
  }));
  await assertFails(updateDoc(doc(db, 'profiles', 'alice'), {
    storagePath: 'users/alice/profile/forged.jpg',
  }));
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

test('client cannot forge another users block', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'blocks', 'bob_charlie'), {
    blockerUid: 'bob',
    blockedUid: 'charlie',
    createdAt: new Date(),
  }));
});

test('client cannot create or delete block state directly', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'blocks', 'alice_bob'), {
    blockerUid: 'alice',
    blockedUid: 'bob',
    createdAt: new Date(),
  }));
  await adminSeed([
    ['blocks', 'alice_bob', {
      blockerUid: 'alice',
      blockedUid: 'bob',
      createdAt: new Date(),
    }],
  ]);
  const existing = await assertSucceeds(getDoc(doc(db, 'blocks', 'alice_bob')));
  if (!existing.exists()) throw new Error('Expected trusted backend block seed.');
  const {deleteDoc} = await import('firebase/firestore');
  await assertFails(deleteDoc(doc(db, 'blocks', 'alice_bob')));
});

test('reporter cannot create a report with resolved moderation status', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'reports', 'r1'), {
    reporterUid: 'alice',
    reportedUid: 'bob',
    reason: 'harassment',
    details: 'test',
    status: 'resolved',
    createdAt: new Date(),
  }));
});

test('reporter cannot change report status after creation', async () => {
  await adminSeed([
    ['reports', 'r1', {
      reporterUid: 'alice',
      reportedUid: 'bob',
      reason: 'harassment',
      details: 'test',
      status: 'open',
      createdAt: new Date(),
    }],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(updateDoc(doc(db, 'reports', 'r1'), {status: 'resolved'}));
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

test('nonparticipant cannot read an unblocked conversation or its messages', async () => {
  await adminSeed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['users', 'charlie', {uid: 'charlie', accountStatus: 'active'}],
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
  ]);
  const db = env.authenticatedContext('charlie').firestore();
  await assertFails(getDoc(doc(db, 'conversations', 'alice_bob')));
  await assertFails(getDoc(doc(db, 'messages', 'm1')));
});

test('participant cannot rewrite another users message content', async () => {
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
  ]);
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(updateDoc(doc(db, 'messages', 'm1'), {text: 'tampered'}));
});
