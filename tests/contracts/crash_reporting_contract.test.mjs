import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

const root = process.cwd();
const read = (relativePath) =>
  fs.readFileSync(path.join(root, relativePath), 'utf8');

const pubspec = read('pubspec.yaml');
const main = read('lib/main.dart');
const settingsGradle = read('android/settings.gradle.kts');
const appGradle = read('android/app/build.gradle.kts');
const androidManifest = read(
  'android/app/src/main/AndroidManifest.xml',
);
const iosPlist = read('ios/Runner/Info.plist');

function collectDartSource(directory) {
  const output = [];

  for (const entry of fs.readdirSync(directory, {
    withFileTypes: true,
  })) {
    const target = path.join(directory, entry.name);

    if (entry.isDirectory()) {
      output.push(collectDartSource(target));
    } else if (entry.isFile() && entry.name.endsWith('.dart')) {
      output.push(fs.readFileSync(target, 'utf8'));
    }
  }

  return output.join('\n');
}

const libSource = collectDartSource(path.join(root, 'lib'));

test('Crash reporting is native-release-only and privacy-minimal', () => {
  assert.match(
    pubspec,
    /^\s*firebase_crashlytics:\s*5\.2\.7\s*$/m,
  );
  assert.doesNotMatch(
    pubspec,
    /^\s*firebase_analytics\s*:/m,
  );

  assert.match(
    settingsGradle,
    /id\("com\.google\.firebase\.crashlytics"\)\s+version\s+"3\.0\.7"\s+apply false/,
  );
  assert.match(
    appGradle,
    /id\("com\.google\.firebase\.crashlytics"\)/,
  );

  assert.match(
    androidManifest,
    /android:name="firebase_crashlytics_collection_enabled"[\s\S]*?android:value="false"/,
  );
  assert.match(
    iosPlist,
    /<key>FirebaseCrashlyticsCollectionEnabled<\/key>\s*<false\/>/,
  );

  assert.match(
    main,
    /final crashReportingEnabled =[\s\S]*?!kIsWeb[\s\S]*?kReleaseMode[\s\S]*?!useFirebaseEmulators[\s\S]*?!localReleaseSmoke;/,
  );
  assert.match(
    main,
    /setCrashlyticsCollectionEnabled\(\s*crashReportingEnabled/,
  );
  assert.match(
    main,
    /FlutterError\.onError[\s\S]*?recordFlutterFatalError/,
  );
  assert.match(
    main,
    /PlatformDispatcher\.instance\.onError/,
  );
  assert.match(
    main,
    /recordError\([\s\S]*?fatal:\s*true/,
  );

  assert.doesNotMatch(
    libSource,
    /FirebaseCrashlytics\.instance\s*\.\s*log\s*\(/,
  );
  assert.doesNotMatch(
    libSource,
    /FirebaseCrashlytics\.instance\s*\.\s*setUserIdentifier\s*\(/,
  );
  assert.doesNotMatch(
    libSource,
    /FirebaseCrashlytics\.instance\s*\.\s*setCustomKey\s*\(/,
  );
});

test('Crash reporting wiring does not change permanent Android identity', () => {
  assert.match(
    appGradle,
    /namespace\s*=\s*"com\.polycircle\.app"/,
  );
  assert.match(
    appGradle,
    /applicationId\s*=\s*"com\.polycircle\.app"/,
  );
});
