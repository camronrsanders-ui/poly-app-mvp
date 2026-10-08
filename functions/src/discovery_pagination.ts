export const discoverPageSize = 15;
export const maximumDiscoverCandidatePool = 120;
export const discoverSessionLifetimeMs = 30 * 60_000;

const cursorTokenPattern = /^[A-Za-z0-9]{20}$/;

export function normalizeDiscoverPageLimit(value: unknown): number {
  const requested = Number(value ?? discoverPageSize);
  if (!Number.isFinite(requested)) return discoverPageSize;
  return Math.min(
    Math.max(Math.trunc(requested), 1),
    discoverPageSize,
  );
}

export function isValidDiscoverCursorToken(value: unknown): value is string {
  return typeof value === 'string' && cursorTokenPattern.test(value);
}

export function uniqueDiscoverCandidateUids(value: unknown): string[] | null {
  if (!Array.isArray(value) || value.length > maximumDiscoverCandidatePool) {
    return null;
  }

  const unique = new Set<string>();
  for (const item of value) {
    if (typeof item !== 'string' || item.length === 0 || item.length > 128) {
      return null;
    }
    unique.add(item);
  }
  return [...unique];
}
