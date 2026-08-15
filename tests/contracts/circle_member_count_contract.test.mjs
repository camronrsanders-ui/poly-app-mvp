import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const backend = fs.readFileSync(
  'functions/src/circle_membership.ts',
  'utf8',
);

const service = fs.readFileSync(
  'lib/services/circle_membership_service.dart',
  'utf8',
);

const screen = fs.readFileSync(
  'lib/screens/circle/my_circle_screen.dart',
  'utf8',
);

test('new Circles begin with one member', () => {
  assert.match(
    backend,
    /memberCount:\s*1/,
  );
});

test('accepting and leaving update Circle member count', () => {
  assert.match(
    backend,
    /memberCount:[\s\S]*Math\.max[\s\S]*\+\s*1/,
  );

  assert.match(
    backend,
    /memberCount:[\s\S]*Math\.max[\s\S]*-\s*1/,
  );
});

test('Circle summaries expose member count', () => {
  assert.match(
    service,
    /final int memberCount/,
  );

  assert.match(
    screen,
    /memberCount:\s*circle\.memberCount/,
  );

  assert.match(
    screen,
    /active\.memberCount\s*\?\?/,
  );
});
