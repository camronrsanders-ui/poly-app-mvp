import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  ProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>?> getAccount(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await _firestore.collection('profiles').doc(uid).get();
    return doc.data();
  }

  Stream<Map<String, dynamic>?> watchProfile(String uid) => _firestore
      .collection('profiles')
      .doc(uid)
      .snapshots()
      .map((snapshot) => snapshot.data());

  Future<void> saveProfile(String uid, Map<String, dynamic> values) async {
    final ref = _firestore.collection('profiles').doc(uid);
    final existing = await ref.get();
    await ref.set({
      ...values,
      'uid': uid,
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> completeOnboarding(String uid) async {
    // AuthService is responsible for creating the canonical account record.
    // update() fails closed instead of silently creating a partial user document
    // if account bootstrap ever regresses.
    await _firestore.collection('users').doc(uid).update({
      'onboardingComplete': true,
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> isOnboardingComplete(String uid) async {
    final data = await getAccount(uid);
    return data?['onboardingComplete'] == true;
  }
}
