import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'polycircle-privacy-boundary-test',
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

const profile = (uid) => ({
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
  ageMin: 24,
  ageMax: 40,
  distanceRadius: 25,
  preferredStructures: ['Solo poly'],
  preferredIntentions: ['Friendship'],
  profileVisibility: 'public',
  mapVisibility: 'matches_only',
  createdAt: new Date(),
  updatedAt: new Date(),
});

test('another user cannot directly read a public full profile document', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['profiles', 'alice', profile('alice')],
  ]);
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'profiles', 'alice')));
});

test('an active match still cannot read the other users full preference document', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['users', 'bob', {uid: 'bob', accountStatus: 'active'}],
    ['profiles', 'alice', profile('alice')],
    ['matches', 'alice_bob', {userAUid: 'alice', userBUid: 'bob', active: true}],
  ]);
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'profiles', 'alice')));
});

test('profile owner can still read their own full profile document', async () => {
  await seed([
    ['users', 'alice', {uid: 'alice', accountStatus: 'active'}],
    ['profiles', 'alice', profile('alice')],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'profiles', 'alice')));
});

test('like sender can read the like they sent', async () => {
  await seed([
    ['likes', 'alice_bob', {likeId: 'alice_bob', fromUid: 'alice', toUid: 'bob', createdAt: new Date()}],
  ]);
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'likes', 'alice_bob')));
});

test('like recipient cannot inspect incoming interest before a trusted match exists', async () => {
  await seed([
    ['likes', 'alice_bob', {likeId: 'alice_bob', fromUid: 'alice', toUid: 'bob', createdAt: new Date()}],
  ]);
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'likes', 'alice_bob')));
});
