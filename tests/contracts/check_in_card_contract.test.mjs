import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');

const card = fs.readFileSync(
  path.join(root, 'lib/widgets/check_in_card.dart'),
  'utf8',
);

const chat = fs.readFileSync(
  path.join(root, 'lib/screens/messages/chat_screen.dart'),
  'utf8',
);

const rules = fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8');

// Check-ins PR 2 (H-5, H-4, M-14) — design:
// files/check-ins-design-2026-11-18.md, Decisions 3a, 4a, 5a, 6a,
// adopted by the founder 2026-11-18. The card collapses by default so
// the conversation keeps the viewport; freshness is event-driven
// refetch plus an as-of cue, because a Firestore listener would
// require opening the client-denied check-in rules.

test('check-in card starts collapsed; expansion is session-only (H-5)', () => {
  assert.match(card, /bool _expanded = false;/);
  assert.match(card, /Key\('check-in-toggle'\)/);
  assert.match(card, /_expanded = !_expanded/);
  // Nothing expands the card programmatically: no auto-expand on
  // urgent states, no remembered expansion.
  assert.doesNotMatch(card, /_expanded = true/);
});

test('collapsed summary is one line built from the expiry projection', () => {
  assert.match(card, /Key\('check-in-summary'\)/);
  assert.match(card, /maxLines: 1/);
  assert.match(card, /snapshot\.currentMine\(nowMs\)/);
  assert.match(card, /snapshot\.currentOther\(nowMs\)/);
  assert.match(card, /checkInStateLabel\(mine\.state\)/);
  assert.match(card, /checkInStateLabel\(other\.state\)/);
});

test('card exposes the refresh seam and reloads when it fires (H-4)', () => {
  assert.match(card, /final Listenable\? refreshListenable;/);
  assert.match(
    card,
    /refreshListenable\?\.addListener\(_onRefreshSignal\)/,
  );
  assert.match(card, /void _onRefreshSignal\(\)/);
  assert.match(chat, /refreshListenable: _checkInRefreshSignal/);
});

test('as-of cue is stamped on load, rendered, and kept current', () => {
  assert.match(
    card,
    /_loadedAtMs = DateTime\.now\(\)\.millisecondsSinceEpoch;/,
  );
  assert.match(card, /'Updated \$\{_relativeTime\(/);
  assert.match(card, /Timer\.periodic\(/);
  assert.match(card, /Duration\(seconds: 30\)/);
});

test('chat screen refreshes the card on app resume (H-4)', () => {
  assert.match(chat, /with WidgetsBindingObserver/);
  assert.match(chat, /void didChangeAppLifecycleState/);
  assert.match(chat, /AppLifecycleState\.resumed\) _bumpCheckInRefresh\(\)/);
});

test('chat screen refreshes the card after a pushed route returns', () => {
  const push = chat.indexOf('await Navigator.of(context).push(');
  const mounted = chat.indexOf('if (!mounted) return;', push);
  const refresh = chat.indexOf('_bumpCheckInRefresh();', mounted);

  assert.notEqual(push, -1);
  assert.ok(mounted > push);
  assert.ok(refresh > mounted);
});

test('partner message arrivals refresh the card through the debouncer', () => {
  assert.match(chat, /chatPartnerMessageArrived\(/);
  assert.match(chat, /_partnerMessageCheckInRefresh\.tryTrigger\(/);
  assert.match(chat, /class CheckInRefreshDebouncer/);
  assert.match(chat, /Duration\(seconds: 30\)/);
});

test('conversation floor replaces the flat card reserve (H-5)', () => {
  assert.match(chat, /final conversationFloor = math\.max\(/);
  assert.match(chat, /constraints\.maxHeight \* 0\.40/);
  assert.match(chat, /constraints\.maxHeight - 76 - conversationFloor/);
  // The H-5 shape — one flat reserve covering composer and
  // conversation together — may not reappear.
  assert.doesNotMatch(chat, /cardSpace/);
  assert.doesNotMatch(chat, /constraints\.maxHeight - 240/);
});

test('no client read path for check-ins is created (H-4 boundary)', () => {
  // The freshness fix is refetch discipline precisely because this
  // rule must not open: a client listener would bypass the per-read
  // compliance and block guards the callables enforce.
  assert.match(
    rules,
    /match \/connection_check_ins\/\{conversationId\} \{ allow read, write: if false; \}/,
  );
  assert.doesNotMatch(card, /snapshots\(\)|StreamBuilder/);
});

test('shared-note clear asks first; state dialog states visibility', () => {
  assert.match(card, /Clear the shared note\?/);
  assert.match(
    card,
    /onPressed: _busy \? null : _confirmClearSharedNote/,
  );
  assert.match(card, /Your partner will see this note/);
});
