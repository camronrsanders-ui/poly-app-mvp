import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const projectId = 'polycircle-monetization-test';
let env;

before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {rules}});
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env.cleanup();
});

test('authenticated client cannot read backend billing entitlement state', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), '_billing_entitlements', 'alice'), {
      tier: 'premium',
      status: 'active',
      source: 'app_store',
      storeVerified: true,
      accessUntilMs: Date.now() + 60_000,
    });
  });

  const db = env.authenticatedContext('alice').firestore();
  await assertFails(getDoc(doc(db, '_billing_entitlements', 'alice')));
});

test('authenticated client cannot forge its own billing entitlement', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, '_billing_entitlements', 'alice'), {
    tier: 'premium',
    status: 'active',
    source: 'app_store',
    storeVerified: true,
    accessUntilMs: Date.now() + 60_000,
  }));
});
