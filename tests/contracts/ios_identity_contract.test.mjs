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

test('iOS build configurations preserve production and separate staging identities', () => {
  const productionRunner =
    xcode.match(
      /PRODUCT_BUNDLE_IDENTIFIER = com\.polycircle\.app;/g,
    ) ?? [];

  const stagingRunner =
    xcode.match(
      /PRODUCT_BUNDLE_IDENTIFIER = com\.polycircle\.app\.staging;/g,
    ) ?? [];

  const productionRunnerTests =
    xcode.match(
      /PRODUCT_BUNDLE_IDENTIFIER = com\.polycircle\.app\.RunnerTests;/g,
    ) ?? [];

  const stagingRunnerTests =
    xcode.match(
      /PRODUCT_BUNDLE_IDENTIFIER = com\.polycircle\.app\.staging\.RunnerTests;/g,
    ) ?? [];

  assert.equal(productionRunner.length, 3);
  assert.equal(stagingRunner.length, 3);
  assert.equal(productionRunnerTests.length, 3);
  assert.equal(stagingRunnerTests.length, 3);

  assert.doesNotMatch(
    xcode,
    /PRODUCT_BUNDLE_IDENTIFIER = com\.(?:example|mycompany)\.polycircle/,
  );
});

test('iOS host validation recognizes both environment identities', () => {
  assert.match(
    ensureIos,
    /flutter create[\s\S]*--platforms=ios[\s\S]*--org com\.polycircle/,
  );

  assert.match(
    ensureIos,
    /PRODUCT_BUNDLE_IDENTIFIER = com\.polycircle\.app;/,
  );

  assert.match(
    ensureIos,
    /PRODUCT_BUNDLE_IDENTIFIER = com\.polycircle\.app\.staging;/,
  );

  assert.match(ensureIos, /Debug-production/);
  assert.match(ensureIos, /Debug-staging/);
  assert.match(ensureIos, /Release-production/);
  assert.match(ensureIos, /Release-staging/);

  assert.doesNotMatch(
    ensureIos,
    /EXPECTED_IOS_BUNDLE_ID=/,
  );

  assert.match(
    ensureIos,
    /com\.example\.polycircle/,
  );

  assert.match(
    ensureIos,
    /com\.mycompany\.polycircle/,
  );

  assert.match(
    ensureIos,
    /A legacy iOS bundle identifier remains/,
  );
});

test('development preflight selects the requested iOS environment explicitly', () => {
  assert.match(
    preflight,
    /ENVIRONMENT="\$\{1:-\}"/,
  );

  assert.match(preflight, /production\|staging/);

  assert.match(
    preflight,
    /EXPECTED_FIREBASE_PROJECT_ID="poly-circle-j5v6dy"/,
  );

  assert.match(
    preflight,
    /EXPECTED_FIREBASE_PROJECT_ID="polycircle-staging-82204f"/,
  );

  assert.match(
    preflight,
    /EXPECTED_IOS_BUNDLE_ID="com\.polycircle\.app"/,
  );

  assert.match(
    preflight,
    /EXPECTED_IOS_BUNDLE_ID="com\.polycircle\.app\.staging"/,
  );

  assert.match(
    preflight,
    /ios\/Runner\/Firebase\/production\/GoogleService-Info\.plist/,
  );

  assert.match(
    preflight,
    /ios\/Runner\/Firebase\/staging\/GoogleService-Info\.plist/,
  );
});
