import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, test} from 'node:test';
import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {ref, uploadBytes, getBytes, deleteObject} from 'firebase/storage';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8');
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'polycircle-storage-security-test',
    storage: {rules},
  });
});

after(async () => {
  await env.cleanup();
});

test('profile media path is denied to client even for owner', async () => {
  const storage = env.authenticatedContext('alice').storage();
  const target = ref(storage, 'users/alice/profile/avatar.jpg');
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xdb]);
  await assertFails(uploadBytes(target, bytes, {contentType: 'image/jpeg'}));
  await assertFails(getBytes(target));
  await assertFails(deleteObject(target));
});

test('profile quarantine path is denied to Firebase Storage SDK', async () => {
  const storage = env.authenticatedContext('alice').storage();
  const target = ref(storage, 'users/alice/profile_quarantine/upload.jpg');
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xdb]);
  await assertFails(uploadBytes(target, bytes, {contentType: 'image/jpeg'}));
  await assertFails(getBytes(target));
});

test('another user cannot access owner profile media path', async () => {
  const storage = env.authenticatedContext('bob').storage();
  const target = ref(storage, 'users/alice/profile/avatar.jpg');
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xdb]);
  await assertFails(uploadBytes(target, bytes, {contentType: 'image/jpeg'}));
  await assertFails(getBytes(target));
});

test('private-media path is denied to client even for owner', async () => {
  const storage = env.authenticatedContext('alice').storage();
  const target = ref(storage, 'private_media/alice/media1/original.jpg');
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xdb]);
  await assertFails(uploadBytes(target, bytes, {contentType: 'image/jpeg'}));
  await assertFails(getBytes(target));
});

test('unauthenticated client cannot access any media path', async () => {
  const storage = env.unauthenticatedContext().storage();
  const target = ref(storage, 'users/alice/profile/avatar.jpg');
  await assertFails(getBytes(target));
});
