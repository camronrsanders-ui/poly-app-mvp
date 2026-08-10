import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {after, before, beforeEach, test} from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
const projectId = 'polycircle-report-security-test';
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

async function seedActiveUser(uid) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), {uid, accountStatus: 'active'});
  });
}

test('client cannot create reports directly', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'reports', 'report1'), {
    reportId: 'report1',
    reporterUid: 'alice',
    reportedUid: 'bob',
    reason: 'harassment',
    details: 'test',
    status: 'open',
    createdAt: new Date(),
  }));
});

test('active reporter can read a report created by trusted backend', async () => {
  await seedActiveUser('alice');
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'reports', 'report1'), {
      reportId: 'report1',
      reporterUid: 'alice',
      reportedUid: 'bob',
      reason: 'harassment',
      details: 'test',
      status: 'open',
      createdAt: new Date(),
    });
  });

  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'reports', 'report1')));
});

test('reported user cannot read the report against them', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'reports', 'report1'), {
      reportId: 'report1',
      reporterUid: 'alice',
      reportedUid: 'bob',
      reason: 'harassment',
      details: 'test',
      status: 'open',
      createdAt: new Date(),
    });
  });

  const db = env.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'reports', 'report1')));
});
