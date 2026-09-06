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

test('real Circles use only consent-backed Circle members', () => {
  const start =
    circle.indexOf(
      'for (final circle in model.circles)',
    );

  const end =
    circle.indexOf(
      '// Shared Worlds',
      start,
    );

  assert.ok(start >= 0);
  assert.ok(end > start);

  const realCircleBlock =
    circle.slice(start, end);

  assert.match(
    realCircleBlock,
    /circle\.members/,
  );

  assert.match(
    realCircleBlock,
    /final circlePeople/,
  );

  assert.match(
    realCircleBlock,
    /people:\s*circlePeople/,
  );

  assert.doesNotMatch(
    realCircleBlock,
    /people:\s*people\b/,
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
