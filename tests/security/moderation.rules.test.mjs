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
    projectId: 'polycircle-moderation-rules-test',
    firestore: {rules},
  });
});

beforeEach(async () => env.clearFirestore());
after(async () => env.cleanup());

async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', 'alice'), {
      uid: 'alice', email: 'alice@example.test', createdAt: new Date(),
      onboardingComplete: true, lastActiveAt: new Date(), accountStatus: 'active',
    });
    await setDoc(doc(db, 'reports', 'report-1'), {
      reportId: 'report-1',
      reporterUid: 'alice',
      reportedUid: 'bob',
      reason: 'harassment',
      details: 'report details',
      status: 'open',
      createdAt: new Date(),
    });
    await setDoc(doc(db, 'report_moderation', 'report-1'), {
      reportId: 'report-1',
      moderatorUid: 'moderator-user',
      status: 'reviewing',
      note: 'internal-only moderation note',
      updatedAt: new Date(),
    });
    await setDoc(doc(db, 'account_moderation', 'bob'), {
      targetUid: 'bob',
      state: 'suspended',
      reasonCode: 'reported_abuse',
      note: 'internal account note',
      updatedByUid: 'admin-user',
      updatedAt: new Date(),
    });
    await setDoc(doc(db, 'moderation_audit', 'audit-1'), {
      action: 'account_state_changed',
      targetUid: 'bob',
      state: 'suspended',
      reasonCode: 'reported_abuse',
      actorUid: 'admin-user',
      createdAt: new Date(),
    });
  });
}

test('reporter can read their submitted report but no internal moderation collections', async () => {
  await seed();
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'reports', 'report-1')));
  await assertFails(getDoc(doc(db, 'report_moderation', 'report-1')));
  await assertFails(getDoc(doc(db, 'account_moderation', 'bob')));
  await assertFails(getDoc(doc(db, 'moderation_audit', 'audit-1')));
});

test('ordinary authenticated users cannot create or update internal moderation records', async () => {
  await seed();
  const db = env.authenticatedContext('mallory').firestore();
  await assertFails(setDoc(doc(db, 'report_moderation', 'report-2'), {
    reportId: 'report-2',
    moderatorUid: 'mallory',
    status: 'resolved',
    note: 'forged',
    updatedAt: new Date(),
  }));
  await assertFails(updateDoc(doc(db, 'report_moderation', 'report-1'), {
    status: 'dismissed',
  }));
  await assertFails(setDoc(doc(db, 'account_moderation', 'mallory'), {
    targetUid: 'mallory', state: 'active', reasonCode: 'appeal_granted',
    note: 'forged', updatedByUid: 'mallory', updatedAt: new Date(),
  }));
  await assertFails(setDoc(doc(db, 'moderation_audit', 'audit-forged'), {
    action: 'account_state_changed', targetUid: 'mallory', state: 'active',
    reasonCode: 'appeal_granted', actorUid: 'mallory', createdAt: new Date(),
  }));
});

test('reporter cannot forge moderation status on the report document', async () => {
  await seed();
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(updateDoc(doc(db, 'reports', 'report-1'), {
    status: 'resolved',
  }));
});
