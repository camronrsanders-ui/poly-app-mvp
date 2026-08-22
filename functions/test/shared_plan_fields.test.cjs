const test = require('node:test');
const assert = require('node:assert/strict');
const {normalizeSharedPlanInput} = require('../lib/shared_plan_fields.js');

const now = Date.UTC(2026, 7, 22, 12, 0, 0);
const tomorrow = now + (24 * 60 * 60 * 1000);

test('normalizes the deliberately small manual plan model', () => {
  assert.deepEqual(normalizeSharedPlanInput({
    title: ' Dinner ',
    plannedForMs: tomorrow,
    placeLabel: ' Little Barley ',
    note: ' Patio if weather is nice. ',
  }, now), {
    title: 'Dinner',
    plannedForMs: tomorrow,
    placeLabel: 'Little Barley',
    note: 'Patio if weather is nice.',
  });
});

test('requires a bounded future date and time', () => {
  assert.throws(() => normalizeSharedPlanInput({
    title: 'Dinner',
    plannedForMs: now - (60 * 60 * 1000),
  }, now), /date and time/i);

  assert.throws(() => normalizeSharedPlanInput({
    title: 'Dinner',
    plannedForMs: now + (3 * 365 * 24 * 60 * 60 * 1000),
  }, now), /date and time/i);
});

test('rejects calendar, venue automation, and precise coordinates', () => {
  for (const forbidden of [
    {calendarEventId: 'abc'},
    {calendarProvider: 'google'},
    {venueId: 'venue-1'},
    {recommendedVenue: 'Somewhere'},
    {latitude: 42.3, longitude: -71.1},
  ]) {
    assert.throws(() => normalizeSharedPlanInput({
      title: 'Dinner',
      plannedForMs: tomorrow,
      ...forbidden,
    }, now), /manual details only/i);
  }
});

test('rejects severe prohibited UGC in plan copy', () => {
  assert.throws(() => normalizeSharedPlanInput({
    title: 'I will kill you',
    plannedForMs: tomorrow,
  }, now), /prohibited content/i);
});
