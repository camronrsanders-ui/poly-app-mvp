import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

// Product review 2026-11-17, finding H-6: the Safety Center — the
// screen a member in danger opens — carried no crisis resource and
// no link to one, and closed by pointing at "the emergency resources
// appropriate to your location" while 988 sat one undiscoverable
// screen away. The fix renders the canonical Learn crisis resources
// at the TOP of the Safety Center (ratified consent-first order,
// Step 1). These contracts pin that behavior at source level; the
// widget behavior is covered by test/safety_center_test.dart and the
// URI data itself by test/learn_screen_test.dart.

const root = path.resolve(import.meta.dirname, '../..');
const safetyCenter = fs.readFileSync(
  path.join(root, 'lib/screens/safety/safety_center_screen.dart'),
  'utf8',
);
const learnContent = fs.readFileSync(
  path.join(root, 'lib/content/learn_content.dart'),
  'utf8',
);

test('Safety Center renders the canonical Learn crisis resources', () => {
  // One source of truth: the Safety Center reuses LearnContent
  // instead of carrying a second copy of the crisis list that could
  // drift from Get Help.
  assert.match(safetyCenter, /LearnContent\.crisisResources/);
  assert.match(safetyCenter, /LearnContent\.helpCardHeading/);
  assert.match(safetyCenter, /import '..\/..\/content\/learn_content\.dart';/);
});

test('crisis help sits above the Safety Center explainer cards', () => {
  const crisisAt = safetyCenter.indexOf('_crisisHelpCard(context)');
  const firstSectionAt = safetyCenter.indexOf("'Block at any time'");
  assert.ok(crisisAt >= 0, 'Safety Center must render the crisis card');
  assert.ok(firstSectionAt >= 0, 'explainer sections must still exist');
  assert.ok(
    crisisAt < firstSectionAt,
    'a member in danger must not scroll past the explainer cards to reach a crisis line',
  );
});

test('988 and Call BlackLine keep separate Call and Text actions', () => {
  // The fixed pattern from the 2026-11-11 crisis-button fix: a line
  // that takes calls and texts carries two actions — Call (tel:) and
  // Text (sms:) — never one button labeled "Call or text" that only
  // dials. The Safety Center renders these same actions.
  assert.match(
    learnContent,
    /CrisisAction\(label: 'Call', uri: 'tel:988'\)/,
  );
  assert.match(
    learnContent,
    /CrisisAction\(label: 'Text', uri: 'sms:988'\)/,
  );
  assert.match(
    learnContent,
    /CrisisAction\(label: 'Call', uri: 'tel:\+18006045841'\)/,
  );
  assert.match(
    learnContent,
    /CrisisAction\(label: 'Text', uri: 'sms:\+18006045841'\)/,
  );
  assert.doesNotMatch(learnContent, /label: 'Call or text'/);
});

test('Safety Center launches crisis URIs externally', () => {
  assert.match(safetyCenter, /launchUrl\(/);
  assert.match(safetyCenter, /LaunchMode\.externalApplication/);
  assert.match(safetyCenter, /action\.uri\.startsWith\('sms:'\)/);
});

test('Safety Center links onward to the Learn Get Help page', () => {
  assert.match(safetyCenter, /Get help & learn/);
  assert.match(safetyCenter, /const LearnPage\(\)/);
  assert.match(safetyCenter, /FeatureFlags\.learnEnabled/);
});

test('closing copy points at the on-screen crisis resources', () => {
  assert.doesNotMatch(
    safetyCenter,
    /emergency resources appropriate to your location/,
  );
  assert.match(safetyCenter, /crisis lines at the top of this screen/);
});
