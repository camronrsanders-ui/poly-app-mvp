import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DiscoveryService {
  DiscoveryService({FirebaseAuth? auth, FirebaseFunctions? functions})
      : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<List<Map<String, dynamic>>> loadCandidates({int limit = 30}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final callable = _functions.httpsCallable('listDiscoveryCandidates');
    final result = await callable.call<Map<String, dynamic>>({'limit': limit});
    final raw = result.data['candidates'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
