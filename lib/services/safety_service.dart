import 'package:cloud_firestore/cloud_firestore.dart';

class SafetyService {
  SafetyService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String blockId(String blockerUid, String blockedUid) => '${blockerUid}_$blockedUid';

  Future<void> blockUser({required String blockerUid, required String blockedUid}) async {
    await _firestore.collection('blocks').doc(blockId(blockerUid, blockedUid)).set({
      'blockerUid': blockerUid,
      'blockedUid': blockedUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser({required String blockerUid, required String blockedUid}) async {
    await _firestore.collection('blocks').doc(blockId(blockerUid, blockedUid)).delete();
  }

  Future<void> reportUser({
    required String reporterUid,
    required String reportedUid,
    required String reason,
    String details = '',
  }) async {
    await _firestore.collection('reports').add({
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'reason': reason,
      'details': details.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }

  Future<Set<String>> getBlockedUserIds(String uid) async {
    final outgoing = await _firestore.collection('blocks').where('blockerUid', isEqualTo: uid).get();
    final incoming = await _firestore.collection('blocks').where('blockedUid', isEqualTo: uid).get();
    return {
      ...outgoing.docs.map((d) => d.data()['blockedUid'] as String),
      ...incoming.docs.map((d) => d.data()['blockerUid'] as String),
    };
  }
}
