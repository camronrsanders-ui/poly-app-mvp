class FeatureFlags {
  const FeatureFlags._();

  /// Private Vault stays disabled until P0 safety/security issue #2 is closed
  /// and release-gate requirements have passed in CI/emulators.
  static const bool privateVaultEnabled = false;

  /// Future visual polycule graph is intentionally deferred until the
  /// relationship-card MVP is stable and privacy behavior is fully tested.
  static const bool visualPolyculeGraphEnabled = false;

  /// AI compatibility scoring is not part of MVP. Discovery remains
  /// transparent/rule-based until explicitly designed and reviewed.
  static const bool aiCompatibilityEnabled = false;
}
