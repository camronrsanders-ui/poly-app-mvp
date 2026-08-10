import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SafetyService {
  SafetyService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String blockId(String blockerUid, String blockedUid) => '${blockerUid}_$blockedUid';

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    return uid;
  }

  Future<void> blockUser(String blockedUid) async {
    final blockerUid = _requireUid();
    if (blockerUid == blockedUid) throw ArgumentError('You cannot block yourself.');

    final callable = _functions.httpsCallable('blockUser');
    await callable.call(<String, dynamic>{'blockedUid': blockedUid});
  }

  Future<void> unblockUser(String blockedUid) async {
    final blockerUid = _requireUid();
    if (blockerUid == blockedUid) throw ArgumentError('You cannot unblock yourself.');

    final callable = _functions.httpsCallable('unblockUser');
    await callable.call(<String, dynamic>{'blockedUid': blockedUid});
  }

  Future<List<Map<String, dynamic>>> listBlockedUsers() async {
    _requireUid();
    final callable = _functions.httpsCallable('listMyBlocks');
    final result = await callable.call<Map<String, dynamic>>();
    final raw = result.data['blocks'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => (item['blockedUid']?.toString() ?? '').isNotEmpty)
        .toList(growable: false);
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

    final callable = _functions.httpsCallable('submitReport');
    await callable.call(<String, dynamic>{
      'reportedUid': reportedUid,
      'reason': safeReason,
      'details': safeDetails,
    });
  }

  Future<Set<String>> getBlockedUserIds() async {
    final uid = _requireUid();
    final outgoing = await _firestore
        .collection('blocks')
        .where('blockerUid', isEqualTo: uid)
        .get();
    return outgoing.docs
        .map((d) => d.data()['blockedUid'])
        .whereType<String>()
        .toSet();
  }
}
