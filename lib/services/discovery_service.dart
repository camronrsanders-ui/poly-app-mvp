import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DiscoveryService {
  DiscoveryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<List<Map<String, dynamic>>> loadCandidates({int limit = 30}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final blocked = await _blockedUserIds(uid);
    final alreadyLiked = await _outgoingLikeIds(uid);
    final snapshot = await _firestore
        .collection('profiles')
        .where('profileVisibility', isEqualTo: 'public')
        .limit(limit)
        .get();

    final candidates = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      if (doc.id == uid || blocked.contains(doc.id) || alreadyLiked.contains(doc.id)) continue;
      final data = doc.data();
      if (data['openToConnections'] == false) continue;

      // Never rely only on public profile data for account moderation state.
      final account = await _firestore.collection('users').doc(doc.id).get();
      if (account.data()?['accountStatus'] != 'active') continue;

      candidates.add({...data, 'uid': doc.id});
    }
    return candidates;
  }

  Future<Set<String>> _outgoingLikeIds(String uid) async {
    final likes = await _firestore.collection('likes').where('fromUid', isEqualTo: uid).get();
    return likes.docs.map((d) => d.data()['toUid'] as String? ?? '').where((id) => id.isNotEmpty).toSet();
  }

  Future<Set<String>> _blockedUserIds(String uid) async {
    final outgoing = await _firestore.collection('blocks').where('blockerUid', isEqualTo: uid).get();
    final incoming = await _firestore.collection('blocks').where('blockedUid', isEqualTo: uid).get();

    return {
      ...outgoing.docs.map((d) => d.data()['blockedUid'] as String? ?? ''),
      ...incoming.docs.map((d) => d.data()['blockerUid'] as String? ?? ''),
    }..remove('');
  }
}
