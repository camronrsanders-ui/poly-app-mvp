const test = require('node:test');
const assert = require('node:assert/strict');
const {normalizeSharedMomentInput} = require('../lib/shared_moment_fields.js');

test('normalizes note moments without adding location data', () => {
  assert.deepEqual(normalizeSharedMomentInput({
    kind: 'note',
    title: ' First picnic ',
    note: ' We stayed until sunset. ',
  }), {
    kind: 'note',
    title: 'First picnic',
    note: 'We stayed until sunset.',
    placeLabel: '',
    mediaId: '',
  });
});

test('requires a human-readable place label for place moments', () => {
  assert.throws(() => normalizeSharedMomentInput({
    kind: 'place',
    title: 'Coffee date',
  }), /place label/i);

  assert.equal(normalizeSharedMomentInput({
    kind: 'place',
    title: 'Coffee date',
    placeLabel: 'Little Barley Coffee Shop',
  }).placeLabel, 'Little Barley Coffee Shop');
});

test('rejects precise coordinates in shared-moment payloads', () => {
  assert.throws(() => normalizeSharedMomentInput({
    kind: 'place',
    title: 'Coffee date',
    placeLabel: 'Cafe',
    latitude: 42.3,
    longitude: -71.1,
  }), /precise location coordinates/i);
});

test('validates reserved photo references even while photo publishing stays gated', () => {
  assert.equal(normalizeSharedMomentInput({
    kind: 'photo',
    title: 'Sunset hike',
    mediaId: 'media:abc_123',
  }).mediaId, 'media:abc_123');

  assert.throws(() => normalizeSharedMomentInput({
    kind: 'photo',
    title: 'Sunset hike',
    mediaId: '../raw-storage-path',
  }), /media reference/i);
});

test('rejects severe prohibited UGC in moment text', () => {
  assert.throws(() => normalizeSharedMomentInput({
    kind: 'note',
    title: 'I will kill you',
  }), /prohibited content/i);
});
