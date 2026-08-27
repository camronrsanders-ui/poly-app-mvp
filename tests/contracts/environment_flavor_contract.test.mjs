import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');

const project = fs.readFileSync(
  path.join(root, 'ios/Runner.xcodeproj/project.pbxproj'),
  'utf8',
);

const productionScheme = fs.readFileSync(
  path.join(
    root,
    'ios/Runner.xcodeproj/xcshareddata/xcschemes/production.xcscheme',
  ),
  'utf8',
);

const stagingScheme = fs.readFileSync(
  path.join(
    root,
    'ios/Runner.xcodeproj/xcshareddata/xcschemes/staging.xcscheme',
  ),
  'utf8',
);

const selector = fs.readFileSync(
  path.join(root, 'tool/select_ios_firebase_config.sh'),
  'utf8',
);

const runtime = fs.readFileSync(
  path.join(root, 'tool/ensure_ios_runtime.sh'),
  'utf8',
);

const infoPlist = fs.readFileSync(
  path.join(root, 'ios/Runner/Info.plist'),
  'utf8',
);

test('iOS defines explicit production and staging build environments', () => {
  for (const configuration of [
    'Debug-production',
    'Profile-production',
    'Release-production',
    'Debug-staging',
    'Profile-staging',
    'Release-staging',
  ]) {
    assert.match(project, new RegExp(configuration));
  }

  assert.match(
    project,
    /PRODUCT_BUNDLE_IDENTIFIER = com\.polycircle\.app;/,
  );

  assert.match(
    project,
    /PRODUCT_BUNDLE_IDENTIFIER = com\.polycircle\.app\.staging;/,
  );

  assert.match(
    project,
    /POLYCIRCLE_APP_DISPLAY_NAME = "Polycircle Staging";/,
  );

  assert.match(
    infoPlist,
    /<string>\$\(POLYCIRCLE_APP_DISPLAY_NAME\)<\/string>/,
  );
});

test('iOS shared schemes bind to their matching configurations', () => {
  assert.match(
    productionScheme,
    /buildConfiguration = "Debug-production"/,
  );

  assert.match(
    productionScheme,
    /buildConfiguration = "Profile-production"/,
  );

  assert.match(
    productionScheme,
    /buildConfiguration = "Release-production"/,
  );

  assert.match(
    stagingScheme,
    /buildConfiguration = "Debug-staging"/,
  );

  assert.match(
    stagingScheme,
    /buildConfiguration = "Profile-staging"/,
  );

  assert.match(
    stagingScheme,
    /buildConfiguration = "Release-staging"/,
  );
});

test('iOS Firebase selection is build-time and fails closed', () => {
  assert.match(selector, /poly-circle-j5v6dy/);
  assert.match(selector, /polycircle-staging-82204f/);
  assert.match(selector, /com\.polycircle\.app/);
  assert.match(selector, /com\.polycircle\.app\.staging/);
  assert.match(selector, /BUNDLE_ID/);
  assert.match(selector, /PROJECT_ID/);
  assert.match(selector, /Unsupported iOS environment configuration/);
  assert.match(
    selector,
    /Runner\/Firebase\/\$ENVIRONMENT\/GoogleService-Info\.plist/,
  );
});

test('iOS runtime validation preserves both native identities', () => {
  assert.match(runtime, /com\.polycircle\.app/);
  assert.match(runtime, /com\.polycircle\.app\.staging/);
  assert.match(runtime, /Debug-production/);
  assert.match(runtime, /Debug-staging/);

  assert.doesNotMatch(
    runtime,
    /PLIST="ios\/Runner\/GoogleService-Info\.plist"/,
  );
});
