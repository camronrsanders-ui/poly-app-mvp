import 'package:cloud_functions/cloud_functions.dart';

import '../config/compliance_policy.dart';

class ComplianceService {
  ComplianceService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> recordAdultPolicyAcceptance({
    required String ageAssuranceMethod,
    required String ageSignalStatus,
  }) async {
    if (!allowedAgeAssuranceMethods.contains(ageAssuranceMethod)) {
      throw ArgumentError.value(
        ageAssuranceMethod,
        'ageAssuranceMethod',
        'Unsupported age assurance method.',
      );
    }
    if (ageSignalStatus.isEmpty || ageSignalStatus.length > 80) {
      throw ArgumentError.value(
        ageSignalStatus,
        'ageSignalStatus',
        'Invalid age signal status.',
      );
    }

    // Account identity and policy versions are derived by the trusted backend.
    // The client sends only the bounded age-assurance method/status; exact date
    // of birth never leaves this device through this service.
    await _functions.httpsCallable('recordAdultPolicyAcceptance').call({
      'ageAssuranceMethod': ageAssuranceMethod,
      'ageSignalStatus': ageSignalStatus,
    });
  }
}
