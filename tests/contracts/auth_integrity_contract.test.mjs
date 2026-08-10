import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const authService = fs.readFileSync(path.join(root, 'lib/services/auth_service.dart'), 'utf8');
const profileService = fs.readFileSync(path.join(root, 'lib/services/profile_service.dart'), 'utf8');
const app = fs.readFileSync(path.join(root, 'lib/app.dart'), 'utf8');
const signupScreen = fs.readFileSync(path.join(root, 'lib/screens/auth/signup_screen.dart'), 'utf8');
const loginScreen = fs.readFileSync(path.join(root, 'lib/screens/auth/login_screen.dart'), 'utf8');
const onboarding = fs.readFileSync(path.join(root, 'lib/screens/onboarding/onboarding_screen.dart'), 'utf8');

test('failed signup bootstrap rolls back the brand-new Auth identity', () => {
  assert.match(authService, /createUserWithEmailAndPassword/);
  assert.match(authService, /catch \(_\)[\s\S]*await user\.delete\(\)/);
  assert.match(authService, /catch \(_\)[\s\S]*await _auth\.signOut\(\)/);
});

test('login validates the trusted account record before completing', () => {
  assert.match(authService, /final account = await ref\.get\(\)/);
  assert.match(authService, /final status = data\?\['accountStatus'\]/);
  assert.match(authService, /status != 'active' && !deletionPending/);
  assert.match(authService, /await _auth\.signOut\(\)/);
  assert.match(authService, /if \(status == 'active'\)[\s\S]*await ref\.update\(/);
});

test('only a trusted pending-deletion marker can bypass normal active-account login', () => {
  assert.match(authService, /status == 'paused' && data\?\['deletionRequestedAt'\] != null/);
  assert.match(app, /final deletionPending = status == 'paused' && account\['deletionRequestedAt'\] != null/);
  assert.match(app, /_DeletionRecoveryScreen/);
  assert.match(app, /Finish deleting my account/);
  assert.match(app, /if \(status != 'active'\)[\s\S]*_AccountUnavailableScreen/);
});

test('onboarding completion cannot silently create a partial account document', () => {
  const section = profileService.match(/Future<void> completeOnboarding[\s\S]*?Future<bool> isOnboardingComplete/)?.[0] ?? '';
  assert.match(section, /\.doc\(uid\)\.update\(/);
  assert.doesNotMatch(section, /SetOptions\(merge:\s*true\)/);
});

test('auth and onboarding async error paths are mounted-safe and recoverable', () => {
  assert.match(signupScreen, /on FirebaseAuthException catch \(e\)[\s\S]*if \(mounted\)/);
  assert.match(loginScreen, /on FirebaseAuthException catch \(e\)[\s\S]*if \(mounted\)/);
  assert.match(onboarding, /catch \(error, stackTrace\)/);
  assert.match(onboarding, /Your answers are still here/);
  assert.match(onboarding, /if \(!mounted\) return;[\s\S]*widget\.onComplete\(\)/);
});
