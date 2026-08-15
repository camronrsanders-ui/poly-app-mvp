import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/compliance_policy.dart';

enum AgeAssuranceDecision {
  adult,
  minor,
  verificationRequired,
  notShared,
  unavailable,
  error,
}

class AgeAssuranceResult {
  const AgeAssuranceResult({
    required this.decision,
    required this.method,
    this.lowerBound,
    this.upperBound,
    this.platformStatus,
    this.platformSource,
    this.regulatedRegion = false,
  });

  final AgeAssuranceDecision decision;
  final String method;
  final int? lowerBound;
  final int? upperBound;
  final String? platformStatus;
  final String? platformSource;
  final bool regulatedRegion;

  bool get confirmsAdult => decision == AgeAssuranceDecision.adult;
  bool get confirmsMinor => decision == AgeAssuranceDecision.minor;

  factory AgeAssuranceResult.fromPlatformMap(
    Map<dynamic, dynamic> values, {
    required String method,
  }) {
    final rawStatus = values['status']?.toString() ?? 'error';
    final lower = values['lowerBound'];
    final upper = values['upperBound'];
    final lowerBound = lower is num ? lower.toInt() : null;
    final upperBound = upper is num ? upper.toInt() : null;

    AgeAssuranceDecision decision;
    switch (rawStatus) {
      case 'adult':
        decision = AgeAssuranceDecision.adult;
        break;
      case 'minor':
        decision = AgeAssuranceDecision.minor;
        break;
      case 'verification_required':
        decision = AgeAssuranceDecision.verificationRequired;
        break;
      case 'not_shared':
        decision = AgeAssuranceDecision.notShared;
        break;
      case 'unavailable':
        decision = AgeAssuranceDecision.unavailable;
        break;
      default:
        decision = AgeAssuranceDecision.error;
    }

    // Never trust a native status string that contradicts the actual bounds.
    // The 18+ threshold is intentionally duplicated here as a defensive check.
    if (upperBound != null && upperBound < polycircleMinimumAge) {
      decision = AgeAssuranceDecision.minor;
    } else if (lowerBound != null && lowerBound >= polycircleMinimumAge) {
      decision = AgeAssuranceDecision.adult;
    }

    return AgeAssuranceResult(
      decision: decision,
      method: method,
      lowerBound: lowerBound,
      upperBound: upperBound,
      platformStatus: values['platformStatus']?.toString(),
      platformSource: values['source']?.toString(),
      regulatedRegion: values['regulatedRegion'] == true,
    );
  }
}

class AgeAssuranceService {
  static const MethodChannel _channel =
      MethodChannel('com.polycircle.app/age_assurance');

  Future<AgeAssuranceResult> requestAdultSignal() async {
    final String method;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      method = 'apple_declared_age_range';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      method = 'play_age_signals';
    } else {
      return const AgeAssuranceResult(
        decision: AgeAssuranceDecision.unavailable,
        method: 'self_attested_dob_fallback',
      );
    }

    try {
      final result = await _channel.invokeMethod<dynamic>('requestAdultAgeSignal');
      if (result is! Map) {
        return AgeAssuranceResult(
          decision: AgeAssuranceDecision.error,
          method: method,
          platformStatus: 'invalid_native_response',
        );
      }
      return AgeAssuranceResult.fromPlatformMap(result, method: method);
    } on MissingPluginException {
      return AgeAssuranceResult(
        decision: AgeAssuranceDecision.unavailable,
        method: method,
        platformStatus: 'native_bridge_unavailable',
      );
    } on PlatformException catch (error) {
      return AgeAssuranceResult(
        decision: AgeAssuranceDecision.error,
        method: method,
        platformStatus: error.code,
      );
    }
  }
}
