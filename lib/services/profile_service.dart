import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  ProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
    await _firestore.collection('users').doc(uid).set({
      'onboardingComplete': true,
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isOnboardingComplete(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['onboardingComplete'] == true;
  }
}
