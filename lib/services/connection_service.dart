import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConnectionService {
  ConnectionService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

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
}
