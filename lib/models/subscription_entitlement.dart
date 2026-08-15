import '../config/monetization_config.dart';

enum SubscriptionAccessStatus {
  none,
  active,
  gracePeriod,
  expired,
  unavailable,
}

class SubscriptionEntitlement {
  const SubscriptionEntitlement({
    required this.tier,
    required this.status,
    required this.source,
    required this.capabilities,
    this.accessUntil,
  });

  const SubscriptionEntitlement.free({
    this.status = SubscriptionAccessStatus.none,
    this.source = 'none',
  })  : tier = SubscriptionTier.free,
        capabilities = const <PremiumCapability>{},
        accessUntil = null;

  final SubscriptionTier tier;
  final SubscriptionAccessStatus status;
  final String source;
  final Set<PremiumCapability> capabilities;
  final DateTime? accessUntil;

  bool get hasPaidAccess =>
      tier != SubscriptionTier.free &&
      (status == SubscriptionAccessStatus.active ||
          status == SubscriptionAccessStatus.gracePeriod);

  bool has(PremiumCapability capability) =>
      hasPaidAccess && capabilities.contains(capability);

  bool get suppressAds => has(PremiumCapability.adFree);

  factory SubscriptionEntitlement.debug(SubscriptionTier tier) {
    if (tier == SubscriptionTier.free) {
      return const SubscriptionEntitlement.free(source: 'debug_override');
    }
    return SubscriptionEntitlement(
      tier: tier,
      status: SubscriptionAccessStatus.active,
      source: 'debug_override',
      capabilities: capabilitiesForTier(tier),
      accessUntil: DateTime.now().add(const Duration(days: 30)),
    );
  }

  factory SubscriptionEntitlement.fromCallableData(
    Map<Object?, Object?> data,
  ) {
    final tier = switch (data['tier']?.toString()) {
      'plus' => SubscriptionTier.plus,
      'premium' => SubscriptionTier.premium,
      _ => SubscriptionTier.free,
    };

    final status = switch (data['status']?.toString()) {
      'active' => SubscriptionAccessStatus.active,
      'grace_period' => SubscriptionAccessStatus.gracePeriod,
      'expired' => SubscriptionAccessStatus.expired,
      'unavailable' => SubscriptionAccessStatus.unavailable,
      _ => SubscriptionAccessStatus.none,
    };

    final accessUntilMs = data['accessUntilMs'];
    final accessUntil = accessUntilMs is num
        ? DateTime.fromMillisecondsSinceEpoch(accessUntilMs.toInt(), isUtc: true)
        : null;

    final rawCapabilities = data['capabilities'];
    final capabilities = <PremiumCapability>{};
    if (rawCapabilities is Iterable) {
      for (final value in rawCapabilities) {
        switch (value.toString()) {
          case 'advanced_discovery':
            capabilities.add(PremiumCapability.advancedDiscovery);
          case 'more_likes':
            capabilities.add(PremiumCapability.moreLikes);
          case 'rewind':
            capabilities.add(PremiumCapability.rewind);
          case 'incognito':
            capabilities.add(PremiumCapability.incognito);
          case 'ad_free':
            capabilities.add(PremiumCapability.adFree);
          case 'advanced_circle':
            capabilities.add(PremiumCapability.advancedCircle);
        }
      }
    }

    // Fail closed: a malformed/contradictory paid response does not create paid
    // access in the client. Trusted feature authorization must also be checked
    // server-side when a paid capability affects backend behavior.
    final paidStatus = status == SubscriptionAccessStatus.active ||
        status == SubscriptionAccessStatus.gracePeriod;
    if (tier == SubscriptionTier.free || !paidStatus) {
      return SubscriptionEntitlement.free(
        status: status,
        source: data['source']?.toString() ?? 'none',
      );
    }

    return SubscriptionEntitlement(
      tier: tier,
      status: status,
      source: data['source']?.toString() ?? 'unknown',
      capabilities: capabilities,
      accessUntil: accessUntil,
    );
  }
}
