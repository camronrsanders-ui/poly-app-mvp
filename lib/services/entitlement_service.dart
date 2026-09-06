import 'package:cloud_functions/cloud_functions.dart';

import '../config/monetization_config.dart';
import '../models/subscription_entitlement.dart';

class EntitlementService {
  EntitlementService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<SubscriptionEntitlement> loadCurrent() async {
    final debugTier = debugSubscriptionTierOverride;
    if (debugTier != null) {
      return SubscriptionEntitlement.debug(debugTier);
    }

    try {
      final result = await _functions
          .httpsCallable('getMyEntitlements')
          .call<Map<Object?, Object?>>();
      return SubscriptionEntitlement.fromCallableData(result.data);
    } on FirebaseFunctionsException {
      // Entitlement lookup fails closed. A network/backend problem must never
      // turn into paid access. The UI may show a retry state later, but the safe
      // functional fallback is the free tier.
      return const SubscriptionEntitlement.free(
        status: SubscriptionAccessStatus.unavailable,
        source: 'backend_unavailable',
      );
    }
  }
}
