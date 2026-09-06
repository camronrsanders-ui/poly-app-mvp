import fs from 'node:fs';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const chat = fs.readFileSync('lib/screens/messages/chat_screen.dart', 'utf8');
const moments = fs.readFileSync(
  'lib/screens/messages/shared_moments_screen.dart',
  'utf8',
);
const plans = fs.readFileSync(
  'lib/screens/messages/shared_plans_screen.dart',
  'utf8',
);

test('Messages keeps conversation primary while gated tools live in the app bar', () => {
  assert.match(chat, /ConversationSpaceHeader/);
  assert.match(chat, /actions:\s*\[/);
  assert.match(chat, /conversation-shared-moments/);
  assert.match(chat, /conversation-shared-plans/);
  assert.match(chat, /Expanded\([\s\S]*child:\s*_buildMessageContent\(uid\)/);
  assert.doesNotMatch(chat, /NavigationBar\([\s\S]*Shared moments/i);
});

test('Shared Moments is explicit manual history, not automatic memory or an unmoderated photo path', () => {
  assert.match(moments, /A history you choose together/);
  assert.match(moments, /Nothing is saved automatically/);
  assert.match(moments, /createNote\(/);
  assert.match(moments, /createPlace\(/);
  assert.match(moments, /Use a name only — no precise location/);
  assert.doesNotMatch(moments, /createPhoto\(/);
  assert.doesNotMatch(moments, /ImagePicker|image_picker|Geolocator|google_maps_flutter/);
});

test('Shared Plans UI stays deliberately small and manual', () => {
  assert.match(plans, /Make something to look forward to/);
  assert.match(plans, /showDatePicker\(/);
  assert.match(plans, /showTimePicker\(/);
  assert.match(plans, /_service\.create\(/);
  assert.match(plans, /_service\.update\(/);
  assert.match(plans, /_service\.cancel\(/);
  assert.match(plans, /No automatic calendar or location sharing/);
  assert.doesNotMatch(
    plans,
    /calendarEventId|calendarProvider|recommendedVenue|venueId|Geolocator|google_maps_flutter|latitude|longitude/,
  );
});

test('creator controls are explicit and cancellation remains visible history', () => {
  assert.match(plans, /plan\.creatorUid == uid/);
  assert.match(plans, /final active = plan\.status == 'active'/);
  assert.match(plans, /if \(mine && active\)/);
  assert.doesNotMatch(plans, /if \(mine && !cancelled\)/);
  assert.match(plans, /The plan will stay in your shared history marked as cancelled/);
  assert.match(plans, /_cancelledStatusLabel\(context, plan\)/);
  assert.match(plans, /if \(cancelledAt == null\) return 'Cancelled'/);
});
