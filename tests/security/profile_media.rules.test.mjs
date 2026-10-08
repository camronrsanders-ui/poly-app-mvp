import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const projectId = 'polycircle-profile-media-security-test';
let env;

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

async function seedProfileMedia() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'profile_media', 'photo1'), {
      photoId: 'photo1',
      ownerUid: 'alice',
      storagePath: 'users/alice/profile_quarantine/photo1.jpg',
      contentType: 'image/jpeg',
      status: 'pending_processing',
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });
}

test('profile media owner cannot directly read backend-only metadata', async () => {
  await seedProfileMedia();
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(getDoc(doc(db, 'profile_media', 'photo1')));
});

test('unrelated user cannot read profile media metadata', async () => {
  await seedProfileMedia();
  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'profile_media', 'photo1')));
});

test('client cannot forge profile media processing state', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'profile_media', 'forged'), {
    photoId: 'forged',
    ownerUid: 'alice',
    storagePath: 'users/alice/profile/forged.jpg',
    contentType: 'image/jpeg',
    status: 'active',
  }));
});

test('owner cannot mark quarantined profile media active directly', async () => {
  await seedProfileMedia();
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(updateDoc(doc(db, 'profile_media', 'photo1'), {status: 'active'}));
});

test('owner cannot directly delete profile media metadata', async () => {
  await seedProfileMedia();
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(deleteDoc(doc(db, 'profile_media', 'photo1')));
});
