export type SharedMomentKind = 'note' | 'place' | 'photo';

export interface SharedMomentInput {
  kind: SharedMomentKind;
  title: string;
  note: string;
  placeLabel: string;
  mediaId: string;
}

const severePatterns = [
  /(i will|i am going to)\s+(kill|rape|hurt)\s+(you|u)/i,
  /kill\s+yourself/i,
  /(looking\s+for|seeking|want\s+to\s+meet|dm\s+me\s+if).{0,32}(minor|underage|child|kid)/i,
  /(sex|nudes?|naked|porn|explicit).{0,24}(with|from|of).{0,24}(minor|underage|child|kid)/i,
  /(minor|underage|child|kid).{0,24}(sex|nudes?|naked|porn|explicit)/i,
];

function text(value: unknown, label: string, maxLength: number, required = false): string {
  const normalized = String(value ?? '').trim();
  if ((required && !normalized) || normalized.length > maxLength) {
    throw new Error(`Invalid ${label}.`);
  }
  if (normalized && severePatterns.some((pattern) => pattern.test(normalized))) {
    throw new Error(`${label} contains prohibited content.`);
  }
  return normalized;
}

export function normalizeSharedMomentInput(raw: unknown): SharedMomentInput {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new Error('Invalid shared moment.');
  }
  const data = raw as Record<string, unknown>;
  if (['latitude', 'longitude', 'coordinates', 'geopoint'].some((key) => key in data)) {
    throw new Error('Shared moments cannot store precise location coordinates.');
  }

  const kind = String(data.kind ?? '').trim() as SharedMomentKind;
  if (!['note', 'place', 'photo'].includes(kind)) {
    throw new Error('Invalid shared moment kind.');
  }

  const title = text(data.title, 'title', 120, true);
  const note = text(data.note, 'note', 1200);
  const placeLabel = text(data.placeLabel, 'place label', 160, kind === 'place');
  const mediaId = text(data.mediaId, 'media reference', 128, kind === 'photo');

  if (mediaId && !/^[A-Za-z0-9:_-]+$/.test(mediaId)) {
    throw new Error('Invalid media reference.');
  }

  return {kind, title, note, placeLabel, mediaId};
}
