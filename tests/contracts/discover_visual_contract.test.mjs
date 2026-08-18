import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const shell = read('lib/screens/main_shell.dart');
const discover = read('lib/screens/discover/discover_screen.dart');
const orbit = read('lib/widgets/discovery_orbit.dart');

test('Discover uses one shared Flutter presentation on iOS and Android', () => {
  for (const source of [shell, discover, orbit]) {
    assert.doesNotMatch(source, /Platform\.(?:isIOS|isAndroid)/);
    assert.doesNotMatch(source, /defaultTargetPlatform/);
  }
  assert.match(shell, /const DiscoverScreen\(\)/);
  assert.match(discover, /DiscoveryOrbit\(/);
});

test('Discover owns an immersive header while preserving Safety center access', () => {
  assert.match(shell, /discoverSelected \|\| _index == 2/);
  assert.match(shell, /discover-dark-navigation/);
  assert.match(discover, /discover-cosmic-world/);
  assert.match(discover, /Explore your orbit/);
  assert.match(discover, /discover-safety-center/);
  assert.match(discover, /discover-radius-control/);
  assert.match(discover, /discover-radius-sheet/);
  assert.match(discover, /SafetyCenterScreen/);
});

test('Orbit scene and world preview are integrated without a surrounding card', () => {
  assert.match(orbit, /discovery-orbit-scene/);
  assert.match(orbit, /discovery-world-preview/);
  assert.match(orbit, /WORLD PREVIEW/);
  assert.match(orbit, /Drag the orbit, tap a person, or use the arrows/);
  assert.match(orbit, /DiscoveryOrbitVisuals/);
  assert.match(orbit, /Clip\.antiAlias/);
  assert.match(discover, /fit: BoxFit\.cover/);
  assert.match(discover, /filterQuality: FilterQuality\.high/);
  assert.doesNotMatch(orbit, /Move around the orbit to discover whose world draws you in/);
});
