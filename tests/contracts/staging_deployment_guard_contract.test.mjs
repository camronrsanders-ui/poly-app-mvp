import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');

const deploy = fs.readFileSync(
  path.join(root, 'tool/deploy_staging.sh'),
  'utf8',
);

const gitignore = fs.readFileSync(
  path.join(root, '.gitignore'),
  'utf8',
);

test('staging deployment is pinned to the dedicated project', () => {
  assert.match(
    deploy,
    /STAGING_PROJECT_ID="polycircle-staging-82204f"/,
  );

  assert.match(
    deploy,
    /PRODUCTION_PROJECT_ID="poly-circle-j5v6dy"/,
  );

  assert.match(
    deploy,
    /--project "\$STAGING_PROJECT_ID"/,
  );

  assert.match(
    deploy,
    /--only "\$COMPONENT"/,
  );
});

test('wrapper requires one approved exact head and remote parity', () => {
  assert.match(deploy, /--approved-head/);
  assert.match(deploy, /git rev-parse HEAD/);
  assert.match(deploy, /CURRENT_HEAD" == "\$APPROVED_HEAD/);
  assert.match(deploy, /origin\/restart-foundation/);
});

test('wrapper requires exactly one whitelisted component', () => {
  assert.match(
    deploy,
    /firestore:rules\|firestore:indexes\|storage\|functions/,
  );

  assert.match(
    deploy,
    /exactly one deploy component is permitted/,
  );

  assert.match(
    deploy,
    /explicit deploy component is required/,
  );
});

test('wrapper fails closed on staged or deployment-sensitive tracked changes', () => {
  assert.match(deploy, /git diff --cached --quiet/);

  assert.match(
    deploy,
    /deployment-sensitive files have local changes/,
  );

  assert.match(deploy, /firebase\.json/);
  assert.match(deploy, /firestore\.rules/);
  assert.match(deploy, /firestore\.indexes\.json/);
  assert.match(deploy, /storage\.rules/);
  assert.match(deploy, /functions\/src/);
  assert.match(deploy, /tool\/deploy_staging\.sh/);

  assert.doesNotMatch(deploy, /\.firebaserc/);
});

test('wrapper requires the Functions Node runtime and exact lockfile install', () => {
  assert.match(deploy, /NODE_MAJOR=/);
  assert.match(deploy, /NODE_MAJOR" == "22"/);
  assert.match(deploy, /staging Functions require Node 22/);
  assert.match(deploy, /ci --ignore-scripts/);
});

test('wrapper validates build, contracts, and security before live deploy', () => {
  assert.match(deploy, /run build/);
  assert.match(deploy, /--test tests\/contracts\/\*\.test\.mjs/);
  assert.match(deploy, /security_static_scan\.sh/);

  const lockedInstall = deploy.indexOf('ci --ignore-scripts');
  const build = deploy.indexOf('run build');
  const checkOnlyExit = deploy.indexOf(
    'STAGING DEPLOYMENT CHECK PASSED — NO DEPLOYMENT PERFORMED',
  );
  const liveDeploy = deploy.indexOf('"$FIREBASE_BIN" deploy');

  assert.notEqual(lockedInstall, -1);
  assert.notEqual(build, -1);
  assert.notEqual(checkOnlyExit, -1);
  assert.notEqual(liveDeploy, -1);
  assert.ok(lockedInstall < build);
  assert.ok(checkOnlyExit < liveDeploy);
});

test('local Firebase aliases stay ignored and are not trusted by the wrapper', () => {
  assert.match(gitignore, /^\.firebaserc$/m);
  assert.doesNotMatch(deploy, /firebase use/);
});
