import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const read = (path) => fs.readFileSync(path, 'utf8');

const hub = read('docs/legal/legal-hub.md');
const releaseGates = read('docs/release-gates.md');
const privacyDraft = read('docs/privacy-policy-draft.md');
const termsDraft = read('docs/terms-draft.md');

test('legal hub cannot be mistaken for a compliance guarantee or attorney opinion', () => {
  assert.match(hub, /not legal advice/i);
  assert.match(hub, /does\s+(?:\*\*)?not(?:\*\*)?\s+guarantee/i);
  assert.match(hub, /qualified attorney/i);
  assert.match(hub, /fully legally compliant/i);
});

test('public release gate is explicitly coupled to the legal control center', () => {
  assert.match(releaseGates, /docs\/legal\/legal-hub\.md/);
  assert.match(releaseGates, /RED — PUBLIC-LAUNCH BLOCKER/);
  assert.match(releaseGates, /qualified-counsel disposition/i);
  assert.match(releaseGates, /Final legal launch review\/signoff/i);
});

test('TAKE IT DOWN operational deadline and non-account access remain hard gates', () => {
  assert.match(hub, /TAKE IT DOWN Act/i);
  assert.match(hub, /48 hours/i);
  assert.match(hub, /does not require a Polycircle account/i);
  assert.match(hub, /known identical copies/i);
  assert.match(releaseGates, /48-hour valid-request handling/);
});

test('child exploitation reporting and controlled evidence handling remain explicit', () => {
  assert.match(hub, /18 U\.S\.C\. § 2258A/);
  assert.match(hub, /NCMEC/);
  assert.match(hub, /CyberTipline/);
  assert.match(hub, /unnecessarily downloading, duplicating, forwarding/);
  assert.match(releaseGates, /§ 2258A\/NCMEC CyberTipline/);
});

test('DMCA safe-harbor strategy retains agent, notice, counter-notice and repeat-infringer controls', () => {
  assert.match(hub, /DMCA § 512/);
  assert.match(hub, /designated DMCA agent/i);
  assert.match(hub, /counter-notice/i);
  assert.match(hub, /repeat-infringer/i);
  assert.match(releaseGates, /DMCA § 512 safe-harbor strategy/);
});

test('privacy, deletion, store and legal-process obligations remain launch work', () => {
  assert.match(hub, /Privacy Policy/);
  assert.match(hub, /external web deletion resource/i);
  assert.match(hub, /Restrict Minor Access/);
  assert.match(hub, /law-enforcement\/civil-process policy/i);
  assert.match(hub, /trademark clearance/i);
  assert.match(hub, /launch-jurisdiction privacy-law matrix/i);
});

test('draft public legal documents remain explicitly non-final', () => {
  assert.match(privacyDraft, /NOT FOR PUBLICATION/i);
  assert.match(privacyDraft, /legal.*review/i);
  assert.match(termsDraft, /NOT FOR PUBLICATION/i);
  assert.match(termsDraft, /LEGAL REVIEW/i);
});

test('real billing, ads and private intimate-media expansion remain gated', () => {
  assert.match(hub, /currently OFF/i);
  assert.match(hub, /BLOCKER BEFORE REAL BILLING/i);
  assert.match(hub, /BLOCKER BEFORE REAL ADS/i);
  assert.match(hub, /Private Vault remains outside the released product/i);
});
