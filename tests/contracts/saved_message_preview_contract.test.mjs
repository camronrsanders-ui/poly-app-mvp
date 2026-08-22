import fs from 'node:fs';
import path from 'node:path';
import {test} from 'node:test';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), 'utf8');

const backend = read('functions/src/shared_moments.ts');
const preview = read('functions/src/shared_moment_preview.ts');
const service = read('lib/services/shared_moments_service.dart');
const screen = read('lib/screens/messages/shared_moments_screen.dart');

const createWrite = backend.match(/await ref\.set\(\{([\s\S]*?)\n    \}\);/);

test('saved-message previews and provenance are resolved only at read time', () => {
  assert.match(backend, /const sourceMessageIds = new Set<string>\(\)/);
  assert.match(backend, /await db\.getAll\(/);
  assert.match(backend, /safeSharedMomentMessagePreview\(\s*source\.data\(\),\s*conversationId/);
  assert.match(backend, /const sourcePreview = sourceMessagePreviews\.get\(sourceMessageId\)/);
  assert.match(backend, /sourceMessagePreview:\s*sourcePreview\?\.text \?\? ''/);
  assert.match(backend, /sourceMessageFromCaller:\s*sourcePreview\?\.senderUid === uid/);
  assert.match(preview, /data\.conversationId !== conversationId/);
  assert.match(preview, /data\.messageType !== 'text'/);
  assert.match(preview, /data\.isDeleted === true/);
  assert.match(preview, /typeof data\.senderUid === 'string'/);
});

test('source preview text and provenance are never persisted into the shared-moment record', () => {
  assert.ok(createWrite, 'Expected the trusted shared-moment write block.');
  assert.doesNotMatch(
    createWrite[1],
    /sourceMessagePreview|sourceMessageText|sourceMessageFromCaller/,
  );
  assert.match(createWrite[1], /sourceMessageId:\s*input\.sourceMessageId/);
});

test('client treats source context as ephemeral display data with safe attribution', () => {
  assert.match(service, /final String sourceMessagePreview/);
  assert.match(service, /final bool sourceMessageFromCaller/);
  assert.match(service, /data\['sourceMessagePreview'\]/);
  assert.match(service, /data\['sourceMessageFromCaller'\] == true/);
  assert.match(screen, /moment\.sourceMessagePreview\.isNotEmpty/);
  assert.match(screen, /Original message unavailable/);
  assert.match(screen, /sourceMessageFromCaller \? 'You' : widget\.otherDisplayName/);
  assert.match(screen, /Saved by you/);
  assert.match(screen, /Saved by \$\{widget\.otherDisplayName\}/);
  assert.match(screen, /TextOverflow\.ellipsis/);
});
