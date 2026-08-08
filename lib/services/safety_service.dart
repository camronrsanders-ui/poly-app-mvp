import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SafetyService {
  SafetyService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String blockId(String blockerUid, String blockedUid) => '${blockerUid}_$blockedUid';

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    return uid;
  }

  Future<void> blockUser(String blockedUid) async {
    final blockerUid = _requireUid();
    if (blockerUid == blockedUid) throw ArgumentError('You cannot block yourself.');
    await _firestore.collection('blocks').doc(blockId(blockerUid, blockedUid)).set({
      'blockerUid': blockerUid,
      'blockedUid': blockedUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Remove the current user's outgoing like so the client does not retain an
    // interaction it owns after blocking. Reciprocal data remains protected by
    // Firestore block rules and can be cleaned up by trusted backend logic later.
    await _firestore.collection('likes').doc('${blockerUid}_$blockedUid').delete().catchError((_) {});
  }

  Future<void> unblockUser(String blockedUid) async {
    final blockerUid = _requireUid();
    await _firestore.collection('blocks').doc(blockId(blockerUid, blockedUid)).delete();
  }

  Future<void> reportUser({
    required String reportedUid,
    required String reason,
    String details = '',
  }) async {
    final reporterUid = _requireUid();
    if (reporterUid == reportedUid) throw ArgumentError('You cannot report yourself.');
    final safeReason = reason.trim();
    final safeDetails = details.trim();
    if (safeReason.isEmpty || safeReason.length > 80 || safeDetails.length > 2000) {
      throw ArgumentError('Invalid report content.');
    }
    await _firestore.collection('reports').add({
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'reason': safeReason,
      'details': safeDetails,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }

  Future<Set<String>> getBlockedUserIds() async {
    final uid = _requireUid();
    final outgoing = await _firestore.collection('blocks').where('blockerUid', isEqualTo: uid).get();
    final incoming = await _firestore.collection('blocks').where('blockedUid', isEqualTo: uid).get();
    return {
      ...outgoing.docs.map((d) => d.data()['blockedUid'] as String),
      ...incoming.docs.map((d) => d.data()['blockerUid'] as String),
    };
  }
}
