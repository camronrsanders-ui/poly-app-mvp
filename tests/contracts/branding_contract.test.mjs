import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const branding = fs.readFileSync(path.join(root, 'docs/branding.md'), 'utf8');
const installer = fs.readFileSync(path.join(root, 'tool/install_branding.sh'), 'utf8');

const approvedHash = '45ad99e923294cea8d33457c2f4200e82affa10efa5c011cdd691f0bdd392f20';
const approvedFilename = 'a_logo_for_an_app_named_polycircle_is_displayed.png';

test('branding source of truth pins the exact approved dark Polycircle artwork', () => {
  assert.match(branding, new RegExp(approvedFilename.replaceAll('.', '\\.')));
  assert.match(branding, new RegExp(approvedHash));
  assert.match(branding, /Do not silently replace/);
});

test('native icon installer refuses any artwork that does not match the approved master', () => {
  assert.match(installer, new RegExp(approvedHash));
  assert.match(installer, /Logo hash does not match the approved Polycircle artwork/);
  assert.match(installer, /AppIcon\.appiconset/);
  assert.match(installer, /mipmap-xxxhdpi/);
});
