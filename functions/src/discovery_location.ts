export const allowedDiscoveryRadiusMiles = [5, 10, 20, 30, 50, 100] as const;
export const defaultDiscoveryRadiusMiles = 20;

const earthRadiusMiles = 3958.7613;
const maximumLocationAccuracyMeters = 50_000;
const maximumObservationAgeMs = 24 * 60 * 60_000;
const maximumFutureSkewMs = 5 * 60_000;

export type PrivateCoordinate = {
  latitude: number;
  longitude: number;
};

export type DiscoverLocationUpdate = PrivateCoordinate & {
  accuracyMeters: number;
  observedAtMs: number;
};

export function normalizeDiscoveryRadius(value: unknown): number {
  const parsed = Number(value);
  return allowedDiscoveryRadiusMiles.includes(
    parsed as (typeof allowedDiscoveryRadiusMiles)[number],
  )
    ? parsed
    : defaultDiscoveryRadiusMiles;
}

export function privateCoordinateFromData(
  data: Record<string, unknown> | undefined,
): PrivateCoordinate | null {
  if (!data) return null;
  const latitude = Number(data.latitude);
  const longitude = Number(data.longitude);
  if (
    !Number.isFinite(latitude)
    || !Number.isFinite(longitude)
    || latitude < -90
    || latitude > 90
    || longitude < -180
    || longitude > 180
  ) {
    return null;
  }
  return {latitude, longitude};
}

export function parseDiscoverLocationUpdate(
  value: unknown,
  nowMs = Date.now(),
): DiscoverLocationUpdate | null {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  const data = value as Record<string, unknown>;
  const coordinate = privateCoordinateFromData(data);
  const accuracyMeters = Number(data.accuracyMeters);
  const observedAtMs = Number(data.observedAtMs);
  if (
    coordinate == null
    || !Number.isFinite(accuracyMeters)
    || accuracyMeters < 0
    || accuracyMeters > maximumLocationAccuracyMeters
    || !Number.isFinite(observedAtMs)
    || observedAtMs < nowMs - maximumObservationAgeMs
    || observedAtMs > nowMs + maximumFutureSkewMs
  ) {
    return null;
  }
  return {
    ...coordinate,
    accuracyMeters,
    observedAtMs: Math.trunc(observedAtMs),
  };
}

function radians(degrees: number): number {
  return degrees * Math.PI / 180;
}

/** Deterministic great-circle distance used only inside trusted code. */
export function distanceMiles(
  first: PrivateCoordinate,
  second: PrivateCoordinate,
): number {
  const latitudeDelta = radians(second.latitude - first.latitude);
  const longitudeDelta = radians(second.longitude - first.longitude);
  const firstLatitude = radians(first.latitude);
  const secondLatitude = radians(second.latitude);
  const haversine = Math.sin(latitudeDelta / 2) ** 2
    + Math.cos(firstLatitude)
      * Math.cos(secondLatitude)
      * Math.sin(longitudeDelta / 2) ** 2;
  const centralAngle = 2 * Math.atan2(
    Math.sqrt(haversine),
    Math.sqrt(Math.max(0, 1 - haversine)),
  );
  return earthRadiusMiles * centralAngle;
}

export function coordinateIsWithinRadius(
  requester: PrivateCoordinate,
  candidate: PrivateCoordinate,
  radiusMiles: number,
): boolean {
  return distanceMiles(requester, candidate) <= radiusMiles + 1e-9;
}
