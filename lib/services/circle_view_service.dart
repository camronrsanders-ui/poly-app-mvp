import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';


class CircleViewService {
  CircleViewService({FirebaseFunctions? functions, FirebaseAuth? auth})
      : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<List<Map<String, dynamic>>> loadForProfile(String ownerUid) async {
    final viewerUid = _auth.currentUser?.uid;
    if (viewerUid == null) throw StateError('No signed-in user.');
    if (ownerUid.trim().isEmpty) throw ArgumentError('Invalid profile owner.');

    final callable = _functions.httpsCallable('getCircleForProfile');
    late final HttpsCallableResult<Map<String, dynamic>> result;
    try {
      result =
          await callable.call<Map<String, dynamic>>({'ownerUid': ownerUid});
    } on FirebaseFunctionsException catch (error) {
      // A private, blocked, or otherwise restricted Circle is an expected
      // visibility boundary, not a reason to fail the member-profile screen.
      // Do not expose denied details or bypass the trusted Cloud Function.
      if (error.code == 'permission-denied') {
        return const <Map<String, dynamic>>[];
      }
      rethrow;
    }
    final raw = result.data['cards'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}

