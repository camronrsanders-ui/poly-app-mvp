import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConnectionService {
  ConnectionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<bool> likeUser(String toUid) async {
    final fromUid = _auth.currentUser?.uid;
    if (fromUid == null) throw StateError('No signed-in user.');
    if (fromUid == toUid) throw ArgumentError('You cannot like yourself.');

    final callable = _functions.httpsCallable('likeProfile');
    final result = await callable.call<Map<String, dynamic>>({'toUid': toUid});
    return result.data['matched'] == true;
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
