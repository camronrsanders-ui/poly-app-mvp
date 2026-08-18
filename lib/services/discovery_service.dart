import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/discovery_options.dart';

abstract interface class DiscoverRepository {
  Future<List<Map<String, dynamic>>> loadCandidates({int limit = 30});

  Future<int> loadDistanceMiles();

  Future<void> saveDistanceMiles(int distanceMiles);

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime observedAt,
  });
}

class DiscoverLocationRequiredException implements Exception {
  const DiscoverLocationRequiredException();

  @override
  String toString() => 'Nearby discovery needs a current location.';
}

class DiscoveryService implements DiscoverRepository {
  DiscoveryService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  String? get _uid => _auth.currentUser?.uid;

  @override
  Future<List<Map<String, dynamic>>> loadCandidates({int limit = 30}) async {
    if (_uid == null) return [];

    try {
      final callable = _functions.httpsCallable('getDiscoverCandidates');
      final result =
          await callable.call<Map<String, dynamic>>({'limit': limit});
      final raw = result.data['profiles'];
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final reason = details is Map ? details['reason'] : null;
      if (error.code == 'failed-precondition' &&
          reason == 'discover-location-required') {
        throw const DiscoverLocationRequiredException();
      }
      rethrow;
    }
  }

  @override
  Future<int> loadDistanceMiles() async {
    final uid = _uid;
    if (uid == null) return defaultDiscoverDistanceMiles;
    final profile = await _firestore.collection('profiles').doc(uid).get();
    return normalizedDiscoverDistanceMiles(profile.data()?['distanceRadius']);
  }

  @override
  Future<void> saveDistanceMiles(int distanceMiles) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in required.');
    if (!discoverDistanceOptionsMiles.contains(distanceMiles)) {
      throw ArgumentError.value(
        distanceMiles,
        'distanceMiles',
        'Unsupported Discover distance.',
      );
    }
    await _firestore.collection('profiles').doc(uid).update({
      'distanceRadius': distanceMiles,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime observedAt,
  }) async {
    if (_uid == null) throw StateError('Sign in required.');
    final callable = _functions.httpsCallable('updateDiscoverLocation');
    await callable.call<void>({
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'observedAtMs': observedAt.millisecondsSinceEpoch,
    });
  }
}
