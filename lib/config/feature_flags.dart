class FeatureFlags {
  const FeatureFlags._();

  /// Private Vault stays disabled until the dedicated release gate in
  /// docs/release-gates.md is fully satisfied. Closing an issue or completing
  /// backend scaffolding is never sufficient by itself to enable the feature.
  static const bool privateVaultEnabled = false;

  /// Shared Moments has backend/service scaffolding only. Keep the client gate
  /// OFF until the approved conversation UI, protected photo lifecycle, and
  /// staging/device acceptance gates are complete.
  static const bool sharedMomentsEnabled = false;

  /// Shared Plans has backend/service scaffolding only. Keep the client gate
  /// OFF until the structured plan-card UI and staging/device acceptance gates
  /// are complete.
  static const bool sharedPlansEnabled = false;

  /// Future visual polycule graph is intentionally deferred until the
  /// relationship-card MVP is stable and privacy behavior is fully tested.
  static const bool visualPolyculeGraphEnabled = false;

  /// AI compatibility scoring is not part of MVP. Discovery remains
  /// transparent/rule-based until explicitly designed and reviewed.
  static const bool aiCompatibilityEnabled = false;
}
