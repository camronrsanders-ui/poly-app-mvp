// H-10 (Step 2 PR 4): the field-level projection of one relationship
// card for the Circle view, extracted from circle_view.ts in the repo's
// testable-module pattern so the identity boundary is unit-tested
// without a database.
//
// Until a bilateral consent path exists, a card's display name and
// free-text note are the owner's private data: either field can
// identify a third person who has never been asked. The projection
// therefore includes them only when `redactIdentity` is false, which
// the callable passes exclusively for the owner's own view. Stored
// card documents are never rewritten (render-private, not a data
// migration): if a consent path ships, stored visibility becomes
// meaningful again for consented cards.
import type {DocumentData} from 'firebase-admin/firestore';

export function projectCircleCard(
  cardId: string,
  data: DocumentData,
  redactIdentity: boolean,
): DocumentData {
  return {
    cardId,
    label: String(data.label ?? '').slice(0, 100),
    connectionType: String(data.connectionType ?? '').slice(0, 100),
    status: String(data.status ?? '').slice(0, 80),
    visibility: String(data.visibility ?? 'private'),
    sortOrder: Number(data.sortOrder ?? 0),
    ...(!redactIdentity && typeof data.displayNameOptional === 'string'
      ? {displayNameOptional: data.displayNameOptional.slice(0, 100)}
      : {}),
    ...(!redactIdentity && typeof data.note === 'string'
      ? {note: data.note.slice(0, 1000)}
      : {}),
  };
}
