import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) =>
  fs.readFileSync(path.join(root, relativePath), 'utf8');

const xcode = read('ios/Runner.xcodeproj/project.pbxproj');
const ensureIos = read('tool/ensure_ios_runtime.sh');
const preflight = read('tool/dev_preflight.sh');

test('all active iOS build configurations use the permanent Polycircle bundle namespace', () => {
  const runner =
    xcode.match(/PRODUCT_BUNDLE_IDENTIFIER = com\.polycircle\.app;/g) ?? [];
  const runnerTests =
    xcode.match(
      /PRODUCT_BUNDLE_IDENTIFIER = com\.polycircle\.app\.RunnerTests;/g,
    ) ?? [];

  assert.equal(runner.length, 3);
  assert.equal(runnerTests.length, 3);
  assert.doesNotMatch(
    xcode,
    /PRODUCT_BUNDLE_IDENTIFIER = com\.(?:example|mycompany)\.polycircle/,
  );
});

test('iOS host repair regenerates and normalizes to the permanent namespace', () => {
  assert.match(
    ensureIos,
    /EXPECTED_IOS_BUNDLE_ID="com\.polycircle\.app"/,
  );
  assert.match(
    ensureIos,
    /flutter create --platforms=ios --org com\.polycircle \./,
  );
  assert.match(ensureIos, /com\.polycircle\.app\.RunnerTests/);
  assert.match(ensureIos, /com\.polycircle\.app/);
});

test('development preflight expects the same permanent iOS identity', () => {
  assert.match(
    preflight,
    /EXPECTED_IOS_BUNDLE_ID="com\.polycircle\.app"/,
  );
});
