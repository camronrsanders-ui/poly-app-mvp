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

  Future<List<Map<String, dynamic>>> loadConnections() async {
    if (_auth.currentUser == null) return const [];
    final callable = _functions.httpsCallable('listMyConnections');
    final result = await callable.call<Map<String, dynamic>>();
    final raw = result.data['connections'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> endConnection(String otherUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) throw StateError('No signed-in user.');
    if (currentUid == otherUid) throw ArgumentError('Invalid connection.');

    final callable = _functions.httpsCallable('endConnection');
    final result = await callable.call<Map<String, dynamic>>({'otherUid': otherUid});
    if (result.data['ended'] != true) {
      throw StateError('Connection was not ended.');
    }
  }
}
