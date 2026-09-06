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
          status == SubscriptionAccessStatus.gracePeriod) &&
      accessUntil != null &&
      accessUntil!.isAfter(DateTime.now().toUtc());

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
      accessUntil: DateTime.now().toUtc().add(const Duration(days: 30)),
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
        ? DateTime.fromMillisecondsSinceEpoch(accessUntilMs.toInt(),
            isUtc: true)
        : null;

    // Fail closed: a malformed/contradictory paid response does not create paid
    // access in the client. Trusted feature authorization must also be checked
    // server-side when a paid capability affects backend behavior.
    final paidStatus = status == SubscriptionAccessStatus.active ||
        status == SubscriptionAccessStatus.gracePeriod;
    final accessStillValid =
        accessUntil != null && accessUntil.isAfter(DateTime.now().toUtc());
    if (tier == SubscriptionTier.free || !paidStatus || !accessStillValid) {
      return SubscriptionEntitlement.free(
        status: paidStatus && !accessStillValid
            ? SubscriptionAccessStatus.expired
            : status,
        source: data['source']?.toString() ?? 'none',
      );
    }

    final allowedForTier = capabilitiesForTier(tier);
    final capabilities = <PremiumCapability>{};
    final rawCapabilities = data['capabilities'];
    if (rawCapabilities is Iterable) {
      for (final value in rawCapabilities) {
        final capability = _capabilityFromWire(value.toString());
        if (capability != null && allowedForTier.contains(capability)) {
          capabilities.add(capability);
        }
      }
    }

    return SubscriptionEntitlement(
      tier: tier,
      status: status,
      source: data['source']?.toString() ?? 'unknown',
      capabilities: capabilities,
      accessUntil: accessUntil,
    );
  }

  static PremiumCapability? _capabilityFromWire(String value) {
    return switch (value) {
      'advanced_discovery' => PremiumCapability.advancedDiscovery,
      'more_likes' => PremiumCapability.moreLikes,
      'rewind' => PremiumCapability.rewind,
      'incognito' => PremiumCapability.incognito,
      'ad_free' => PremiumCapability.adFree,
      'advanced_circle' => PremiumCapability.advancedCircle,
      _ => null,
    };
  }
}
