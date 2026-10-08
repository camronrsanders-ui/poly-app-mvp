import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const shell = fs.readFileSync(
  'lib/screens/main_shell.dart',
  'utf8',
);

const selfProfile = fs.readFileSync(
  'lib/screens/profile/self_profile_screen.dart',
  'utf8',
);

const editor = fs.readFileSync(
  'lib/screens/profile/profile_screen.dart',
  'utf8',
);

test('main Profile tab uses the owner-facing self profile', () => {
  assert.match(
    shell,
    /4\s*=>\s*const SelfProfileScreen\(\)/,
  );
});

test('owner-facing Profile exposes logout directly', () => {
  assert.match(
    selfProfile,
    /FirebaseAuth\.instance\.signOut\(\)/,
  );

  assert.match(
    selfProfile,
    /'Log out'/,
  );

  assert.match(
    selfProfile,
    /'Sign out of this device'/,
  );
});

test('logout clears pushed profile routes', () => {
  assert.match(
    selfProfile,
    /popUntil/,
  );

  assert.match(
    editor,
    /Future<void> _signOut/,
  );

  assert.match(
    editor,
    /popUntil/,
  );
});
