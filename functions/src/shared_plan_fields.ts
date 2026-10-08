export interface SharedPlanInput {
  title: string;
  note: string;
  placeLabel: string;
  plannedForMs: number;
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

export function normalizeSharedPlanInput(
  raw: unknown,
  nowMs = Date.now(),
): SharedPlanInput {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new Error('Invalid shared plan.');
  }
  const data = raw as Record<string, unknown>;
  if ([
    'latitude',
    'longitude',
    'coordinates',
    'geopoint',
    'calendarEventId',
    'calendarProvider',
    'venueId',
    'recommendedVenue',
  ].some((key) => key in data)) {
    throw new Error('Shared plans accept manual details only.');
  }

  const title = text(data.title, 'title', 120, true);
  const note = text(data.note, 'note', 1200);
  const placeLabel = text(data.placeLabel, 'place label', 160);
  const plannedForMs = Number(data.plannedForMs);
  const latestAllowed = nowMs + (2 * 365 * 24 * 60 * 60 * 1000);
  if (!Number.isSafeInteger(plannedForMs)
      || plannedForMs < nowMs - (5 * 60 * 1000)
      || plannedForMs > latestAllowed) {
    throw new Error('Invalid plan date and time.');
  }

  return {title, note, placeLabel, plannedForMs};
}
