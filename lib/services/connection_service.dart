import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConnectionService {
  ConnectionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String _likeId(String fromUid, String toUid) => '${fromUid}_$toUid';

  String _matchId(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}_${pair[1]}';
  }

  Future<bool> likeUser(String toUid) async {
    final fromUid = _auth.currentUser?.uid;
    if (fromUid == null) throw StateError('No signed-in user.');
    if (fromUid == toUid) throw ArgumentError('You cannot like yourself.');

    final likeRef = _firestore.collection('likes').doc(_likeId(fromUid, toUid));
    final reciprocalRef = _firestore.collection('likes').doc(_likeId(toUid, fromUid));

    await likeRef.set({
      'fromUid': fromUid,
      'toUid': toUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final reciprocal = await reciprocalRef.get();
    if (!reciprocal.exists) return false;

    final pair = [fromUid, toUid]..sort();
    await _firestore.collection('matches').doc(_matchId(fromUid, toUid)).set({
      'userAUid': pair[0],
      'userBUid': pair[1],
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    }, SetOptions(merge: true));
    return true;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMatches() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('matches')
        .where('active', isEqualTo: true)
        .snapshots();
  }
}
