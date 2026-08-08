import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {ref, uploadBytes, getBytes} from 'firebase/storage';

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

test('owner can upload an allowed profile image', async () => {
  const storage = env.authenticatedContext('alice').storage();
  const target = ref(storage, 'users/alice/profile/avatar.jpg');
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xdb]);
  await assertSucceeds(uploadBytes(target, bytes, {contentType: 'image/jpeg'}));
});

test('another user cannot upload into the owner profile path', async () => {
  const storage = env.authenticatedContext('bob').storage();
  const target = ref(storage, 'users/alice/profile/avatar.jpg');
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xdb]);
  await assertFails(uploadBytes(target, bytes, {contentType: 'image/jpeg'}));
});

test('profile path rejects unsupported content types', async () => {
  const storage = env.authenticatedContext('alice').storage();
  const target = ref(storage, 'users/alice/profile/file.txt');
  await assertFails(uploadBytes(target, new TextEncoder().encode('not an image'), {contentType: 'text/plain'}));
});

test('private-media path is denied to client even for owner', async () => {
  const storage = env.authenticatedContext('alice').storage();
  const target = ref(storage, 'private_media/alice/media1/original.jpg');
  const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xdb]);
  await assertFails(uploadBytes(target, bytes, {contentType: 'image/jpeg'}));
  await assertFails(getBytes(target));
});
