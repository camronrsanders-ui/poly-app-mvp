export type SubscriptionTier = 'free' | 'plus' | 'premium';
export type SubscriptionStatus = 'none' | 'active' | 'grace_period' | 'expired';
export type SubscriptionSource = 'none' | 'app_store' | 'google_play';

export type PublicEntitlement = {
  tier: SubscriptionTier;
  status: SubscriptionStatus;
  source: SubscriptionSource;
  accessUntilMs: number | null;
  capabilities: string[];
  adsSuppressed: boolean;
};

const tierCapabilities: Record<SubscriptionTier, string[]> = {
  free: [],
  plus: [
    'advanced_discovery',
    'more_likes',
    'rewind',
    'incognito',
    'ad_free',
  ],
  premium: [
    'advanced_discovery',
    'more_likes',
    'rewind',
    'incognito',
    'ad_free',
    'advanced_circle',
  ],
};

function freeEntitlement(
  status: SubscriptionStatus = 'none',
  source: SubscriptionSource = 'none',
): PublicEntitlement {
  return {
    tier: 'free',
    status,
    source,
    accessUntilMs: null,
    capabilities: [],
    adsSuppressed: false,
  };
}

function paidTier(value: unknown): SubscriptionTier | null {
  return value === 'plus' || value === 'premium' ? value : null;
}

function paidSource(value: unknown): SubscriptionSource | null {
  return value === 'app_store' || value === 'google_play' ? value : null;
}

function paidStatus(value: unknown): SubscriptionStatus | null {
  return value === 'active' || value === 'grace_period' ? value : null;
}

/**
 * Converts backend-only billing state into the minimum safe entitlement view
 * needed by the app.
 *
 * Paid access is granted only when a trusted store-verification writer has set
 * storeVerified=true, the source is an approved app store, the state is active
 * or grace-period, and the backend access window has not expired. Raw receipts,
 * purchase tokens, transaction identifiers, prices, and billing history are
 * deliberately never returned to the client.
 */
export function resolvePublicEntitlement(
  data: Record<string, unknown> | undefined,
  nowMs = Date.now(),
): PublicEntitlement {
  if (!data) return freeEntitlement();

  const tier = paidTier(data.tier);
  const source = paidSource(data.source);
  const status = paidStatus(data.status);
  const accessUntilMs = typeof data.accessUntilMs === 'number'
    && Number.isFinite(data.accessUntilMs)
    ? Math.trunc(data.accessUntilMs)
    : null;

  if (!tier || !source || !status || data.storeVerified !== true) {
    return freeEntitlement(
      data.status === 'expired' ? 'expired' : 'none',
      source ?? 'none',
    );
  }

  if (accessUntilMs === null || accessUntilMs <= nowMs) {
    return freeEntitlement('expired', source);
  }

  const capabilities = [...tierCapabilities[tier]];
  return {
    tier,
    status,
    source,
    accessUntilMs,
    capabilities,
    adsSuppressed: capabilities.includes('ad_free'),
  };
}
