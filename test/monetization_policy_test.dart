import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/config/monetization_config.dart';
import 'package:polycircle/models/subscription_entitlement.dart';
import 'package:polycircle/services/ad_policy.dart';

void main() {
  test('real billing and ads remain disabled during pre-release', () {
    expect(billingPurchaseFlowEnabled, isFalse);
    expect(advertisingSdkEnabled, isFalse);
  });

  test('free tier has no premium capability', () {
    expect(capabilitiesForTier(SubscriptionTier.free), isEmpty);
  });

  test('plus does not silently receive premium-only Circle capability', () {
    final plus = capabilitiesForTier(SubscriptionTier.plus);
    expect(plus, contains(PremiumCapability.adFree));
    expect(plus, isNot(contains(PremiumCapability.advancedCircle)));
  });

  test('non-paid or expired callable state cannot create paid access', () {
    final expired = SubscriptionEntitlement.fromCallableData({
      'tier': 'premium',
      'status': 'expired',
      'source': 'app_store',
      'capabilities': ['advanced_circle', 'ad_free'],
    });

    expect(expired.tier, SubscriptionTier.free);
    expect(expired.hasPaidAccess, isFalse);
    expect(expired.suppressAds, isFalse);
  });

  test('only Discover intermission is eligible for a future ad placement', () {
    expect(
      AdPolicy.placementMayEverShowAds(AdPlacement.discoverIntermission),
      isTrue,
    );
    for (final placement in AdPlacement.values) {
      if (placement == AdPlacement.discoverIntermission) continue;
      expect(AdPolicy.placementMayEverShowAds(placement), isFalse);
    }
  });

  test('ad requests remain blocked while ad SDK feature is off', () {
    const free = SubscriptionEntitlement.free();
    expect(
      AdPolicy.mayRequestAd(
        placement: AdPlacement.discoverIntermission,
        entitlement: free,
        privacyConsentAllowsAds: true,
      ),
      isFalse,
    );
  });

  test('sensitive member data is explicitly prohibited for ad targeting', () {
    expect(AdPolicy.prohibitedTargetingData, contains('sexual_orientation'));
    expect(AdPolicy.prohibitedTargetingData, contains('gender_identity'));
    expect(
        AdPolicy.prohibitedTargetingData, contains('relationship_structure'));
    expect(AdPolicy.prohibitedTargetingData, contains('profile_age'));
    expect(AdPolicy.prohibitedTargetingData, contains('precise_location'));
    expect(AdPolicy.prohibitedTargetingData, contains('race_or_ethnicity'));
    expect(AdPolicy.prohibitedTargetingData, contains('religion'));
    expect(AdPolicy.prohibitedTargetingData, contains('political_beliefs'));
    expect(AdPolicy.prohibitedTargetingData, contains('messages'));
    expect(AdPolicy.prohibitedTargetingData, contains('reports'));
    expect(
        AdPolicy.prohibitedTargetingData, contains('age_assurance_metadata'));
  });
}
