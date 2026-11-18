const test = require('node:test');
const assert = require('node:assert/strict');
const {projectCircleCard} = require('../lib/circle_card_projection.js');

// H-10 (Step 2 PR 4): the identity matrix for the Circle card
// projection. getCircleForProfile calls projectCircleCard with
// redactIdentity=false only for the owner's own view; every non-owner
// (active match or stranger alike - the callable's per-card visibility
// filter, unchanged, decides whether a card appears at all) is
// projected with redactIdentity=true, so no non-owner payload can
// carry a card's display name or note at any stored visibility. The
// stored document is never rewritten (render-private).

const namedCard = (visibility) => ({
  label: 'Anchor partner',
  connectionType: 'anchor_partner',
  status: 'active',
  visibility,
  sortOrder: 2,
  displayNameOptional: 'Alex Example',
  note: 'Met through friends in 2023.',
});

test('owner projection keeps name and note at every visibility', () => {
  for (const visibility of ['public', 'matches_only', 'private', 'unnamed_public']) {
    const out = projectCircleCard('card-1', namedCard(visibility), false);
    assert.equal(out.displayNameOptional, 'Alex Example');
    assert.equal(out.note, 'Met through friends in 2023.');
    assert.equal(out.visibility, visibility);
  }
});

test('non-owner projection withholds name and note at every visibility', () => {
  // Includes the pre-existing named public card (stored before the
  // interim rule): rendering withholds identity even though the
  // stored visibility was never changed.
  for (const visibility of ['public', 'matches_only', 'private', 'unnamed_public']) {
    const out = projectCircleCard('card-1', namedCard(visibility), true);
    assert.equal('displayNameOptional' in out, false);
    assert.equal('note' in out, false);
    assert.equal(out.label, 'Anchor partner');
    assert.equal(out.connectionType, 'anchor_partner');
    assert.equal(out.status, 'active');
    assert.equal(out.visibility, visibility);
    assert.equal(out.sortOrder, 2);
    assert.equal(out.cardId, 'card-1');
  }
});

test('unnamed cards have no identity fields to leak to non-owners', () => {
  const unnamed = {...namedCard('unnamed_public'), displayNameOptional: '', note: ''};
  const out = projectCircleCard('card-2', unnamed, true);
  assert.equal('displayNameOptional' in out, false);
  assert.equal('note' in out, false);
});

test('projection defaults missing fields the way the callable always has', () => {
  const out = projectCircleCard('card-3', {}, true);
  assert.equal(out.label, '');
  assert.equal(out.connectionType, '');
  assert.equal(out.status, '');
  assert.equal(out.visibility, 'private');
  assert.equal(out.sortOrder, 0);
});

test('owner projection truncates identity fields to the stored limits', () => {
  const long = {
    ...namedCard('private'),
    displayNameOptional: 'n'.repeat(150),
    note: 'x'.repeat(1200),
  };
  const out = projectCircleCard('card-4', long, false);
  assert.equal(out.displayNameOptional.length, 100);
  assert.equal(out.note.length, 1000);
});
