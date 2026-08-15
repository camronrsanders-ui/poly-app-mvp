import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const circle = fs.readFileSync(
  'lib/screens/circle/my_circle_screen.dart',
  'utf8',
);

test('Circle screen loads backend-owned Circles', () => {
  assert.match(
    circle,
    /CircleMembershipService/,
  );

  assert.match(
    circle,
    /listMyCircles/,
  );

  assert.match(
    circle,
    /model\.circles/,
  );
});

test('New launches the real creation experience', () => {
  assert.match(
    circle,
    /showModalBottomSheet<String>/,
  );

  assert.match(
    circle,
    /class _CreateCircleSheet/,
  );

  assert.match(
    circle,
    /createCircle/,
  );

  assert.doesNotMatch(
    circle,
    /Shared Circle creation is the next/,
  );
});

test('real Circles receive unique universe IDs', () => {
  assert.match(
    circle,
    /circle:\$\{circle\.circleId\}/,
  );
});

test('new Circles do not inherit ordinary connections', () => {
  assert.match(
    circle,
    /people:\s*const <Map<String, dynamic>>\[\]/,
  );
});

test('empty Circles remain navigable', () => {
  assert.match(
    circle,
    /_buildEmptyCircleUniverse/,
  );

  assert.match(
    circle,
    /class _EmptyCircleStage/,
  );
});

test('creation UI explains membership consent', () => {
  assert.match(
    circle,
    /nobody joins[\s\S]*accept your invitation/i,
  );

  assert.match(
    circle,
    /membership and[\s\S]*relationship labels[\s\S]*separate consent/i,
  );
});
