import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/compliance_policy.dart';

class ComplianceService {
  ComplianceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> recordAdultPolicyAcceptance({
    required String uid,
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

    await _firestore.collection('users').doc(uid).update({
      'adultAccessApproved': true,
      'termsAcceptedVersion': currentTermsVersion,
      'communityGuidelinesAcceptedVersion':
          currentCommunityGuidelinesVersion,
      'ageAssuranceMethod': ageAssuranceMethod,
      'ageSignalStatus': ageSignalStatus,
      'ageAssuranceCheckedAt': FieldValue.serverTimestamp(),
      'ugcPolicyAcceptedAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }
}
