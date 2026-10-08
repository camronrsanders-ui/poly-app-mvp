import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'polycircle-inactive-account-test',
    firestore: {rules},
  });
});

beforeEach(async () => env.clearFirestore());
after(async () => env.cleanup());

async function seed(accountStatus) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', 'alice'), {
      uid: 'alice',
      email: 'alice@example.test',
      createdAt: new Date(),
      onboardingComplete: true,
      lastActiveAt: new Date(),
      accountStatus,
      ...(accountStatus === 'paused' ? {deletionRequestedAt: new Date()} : {}),
    });
    await setDoc(doc(db, 'users', 'bob'), {
      uid: 'bob',
      email: 'bob@example.test',
      createdAt: new Date(),
      onboardingComplete: true,
      lastActiveAt: new Date(),
      accountStatus: 'active',
    });
    await setDoc(doc(db, 'profiles', 'alice'), {
      uid: 'alice', displayName: 'Alice', age: 30, city: '', region: '', bio: '', headline: '',
      genderIdentity: '', pronouns: '', orientation: '', customIdentityTags: [],
      relationshipStructure: '', relationshipStatus: '', partnered: false, openToConnections: false,
      intentionTags: [], interests: [], lookingForNote: '', ageMin: 18, ageMax: 99,
      distanceRadius: 50, preferredStructures: [], preferredIntentions: [],
      profileVisibility: 'hidden', mapVisibility: 'private', createdAt: new Date(), updatedAt: new Date(),
    });
    await setDoc(doc(db, 'relationship_cards', 'alice-card'), {
      ownerUid: 'alice', label: 'Partner', connectionType: 'romantic_partner',
      displayNameOptional: '', status: 'active', note: '', visibility: 'private',
      sortOrder: 0, isActive: true, createdAt: new Date(), updatedAt: new Date(),
    });
    await setDoc(doc(db, 'matches', 'alice_bob'), {
      matchId: 'alice_bob', userAUid: 'alice', userBUid: 'bob', active: true, createdAt: new Date(),
    });
    await setDoc(doc(db, 'conversations', 'alice_bob'), {
      conversationId: 'alice_bob', participantUids: ['alice', 'bob'], active: true,
      createdAt: new Date(), lastMessageAt: new Date(),
    });
    await setDoc(doc(db, 'messages', 'message-1'), {
      conversationId: 'alice_bob', senderUid: 'bob', text: 'history', createdAt: new Date(),
      isDeleted: false, messageType: 'text', readBy: ['bob'],
    });
    await setDoc(doc(db, 'blocks', 'alice_carol'), {
      blockerUid: 'alice', blockedUid: 'carol', createdAt: new Date(),
    });
    await setDoc(doc(db, 'reports', 'alice-report'), {
      reportId: 'alice-report', reporterUid: 'alice', reportedUid: 'bob', reason: 'spam',
      details: '', status: 'open', createdAt: new Date(),
    });
  });
}

for (const accountStatus of ['paused', 'suspended', 'banned']) {
  test(`${accountStatus} account can read its account marker but cannot use profile/Circle/match/chat/safety data paths`, async () => {
    await seed(accountStatus);
    const db = env.authenticatedContext('alice').firestore();

    await assertSucceeds(getDoc(doc(db, 'users', 'alice')));
    await assertFails(getDoc(doc(db, 'profiles', 'alice')));
    await assertFails(getDoc(doc(db, 'relationship_cards', 'alice-card')));
    await assertFails(getDoc(doc(db, 'matches', 'alice_bob')));
    await assertFails(getDoc(doc(db, 'conversations', 'alice_bob')));
    await assertFails(getDoc(doc(db, 'messages', 'message-1')));
    await assertFails(getDoc(doc(db, 'blocks', 'alice_carol')));
    await assertFails(getDoc(doc(db, 'reports', 'alice-report')));
  });
}

test('paused deletion-recovery account cannot recreate a profile or relationship card', async () => {
  await seed('paused');
  const db = env.authenticatedContext('alice').firestore();

  await assertFails(updateDoc(doc(db, 'profiles', 'alice'), {bio: 'recreated while paused'}));
  await assertFails(setDoc(doc(db, 'relationship_cards', 'new-card'), {
    ownerUid: 'alice', label: 'New', connectionType: 'custom', displayNameOptional: '',
    status: 'active', note: '', visibility: 'private', sortOrder: 1, isActive: true,
    createdAt: new Date(), updatedAt: new Date(),
  }));
});
