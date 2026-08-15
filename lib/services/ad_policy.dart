import '../config/monetization_config.dart';
import '../models/subscription_entitlement.dart';

enum AdPlacement {
  discoverIntermission,
  messages,
  safetyCenter,
  reportFlow,
  blockFlow,
  ageAssurance,
  accountDeletion,
  circle,
  privateVault,
}

/// Encodes the product rule that advertising is secondary to member privacy.
///
/// No ad SDK is installed or initialized yet. When one is added, callers must
/// still satisfy consent/privacy requirements before requesting an ad.
class AdPolicy {
  const AdPolicy._();

  static bool placementMayEverShowAds(AdPlacement placement) {
    return placement == AdPlacement.discoverIntermission;
  }

  static bool mayRequestAd({
    required AdPlacement placement,
    required SubscriptionEntitlement entitlement,
    required bool privacyConsentAllowsAds,
  }) {
    if (!advertisingSdkEnabled) return false;
    if (!privacyConsentAllowsAds) return false;
    if (!placementMayEverShowAds(placement)) return false;
    if (entitlement.suppressAds) return false;
    return true;
  }

  /// Polycircle must not construct ad-targeting profiles from sensitive member
  /// information. Future ad integrations should use contextual placement data
  /// only and must not derive targeting from profile identity, relationship
  /// structure, Circle, messages, reports, blocks, health/intimate data, or age
  /// assurance metadata.
  static const Set<String> prohibitedTargetingData = {
    'sexual_orientation',
    'gender_identity',
    'relationship_structure',
    'circle_relationship_data',
    'messages',
    'blocks',
    'reports',
    'health_or_hiv_data',
    'intimate_media_activity',
    'age_assurance_metadata',
  };
}
