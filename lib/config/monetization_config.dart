import 'package:flutter/foundation.dart';

/// Monetization is deliberately architecture-only during pre-release.
///
/// Do not flip these constants merely to preview paid UI. Real billing and ads
/// require their separate release gates, store configuration, privacy review,
/// and trusted backend verification.
const bool billingPurchaseFlowEnabled = false;
const bool advertisingSdkEnabled = false;

enum SubscriptionTier { free, plus, premium }

enum PremiumCapability {
  advancedDiscovery,
  moreLikes,
  rewind,
  incognito,
  adFree,
  advancedCircle,
}

Set<PremiumCapability> capabilitiesForTier(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.free:
      return const <PremiumCapability>{};
    case SubscriptionTier.plus:
      return const <PremiumCapability>{
        PremiumCapability.advancedDiscovery,
        PremiumCapability.moreLikes,
        PremiumCapability.rewind,
        PremiumCapability.incognito,
        PremiumCapability.adFree,
      };
    case SubscriptionTier.premium:
      return const <PremiumCapability>{
        PremiumCapability.advancedDiscovery,
        PremiumCapability.moreLikes,
        PremiumCapability.rewind,
        PremiumCapability.incognito,
        PremiumCapability.adFree,
        PremiumCapability.advancedCircle,
      };
  }
}

/// Debug-only entitlement preview for internal development.
///
/// Example:
/// `--dart-define=POLYCIRCLE_DEBUG_SUBSCRIPTION_TIER=plus`
///
/// Release/profile builds ignore this value even when somebody supplies the
/// dart-define. It never writes subscription state to Firebase and therefore
/// cannot grant trusted server-side paid privileges.
SubscriptionTier? get debugSubscriptionTierOverride {
  if (!kDebugMode) return null;
  const raw = String.fromEnvironment(
    'POLYCIRCLE_DEBUG_SUBSCRIPTION_TIER',
    defaultValue: '',
  );
  switch (raw.trim().toLowerCase()) {
    case 'free':
      return SubscriptionTier.free;
    case 'plus':
      return SubscriptionTier.plus;
    case 'premium':
      return SubscriptionTier.premium;
    default:
      return null;
  }
}
