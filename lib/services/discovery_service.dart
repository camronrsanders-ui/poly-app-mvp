import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/discovery_options.dart';

const int discoverPageSize = 15;

@immutable
class DiscoverPage {
  const DiscoverPage({
    required this.profiles,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> profiles;
  final String? nextCursor;
  final bool hasMore;
}

abstract interface class DiscoverRepository {
  Future<DiscoverPage> loadCandidates({
    int limit = discoverPageSize,
    String? cursor,
  });

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

class DiscoverSessionExpiredException implements Exception {
  const DiscoverSessionExpiredException();

  @override
  String toString() => 'This Discover session has expired.';
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
  Future<DiscoverPage> loadCandidates({
    int limit = discoverPageSize,
    String? cursor,
  }) async {
    if (_uid == null) {
      return const DiscoverPage(
        profiles: <Map<String, dynamic>>[],
        nextCursor: null,
        hasMore: false,
      );
    }

    try {
      final callable = _functions.httpsCallable('getDiscoverCandidates');
      final result = await callable.call<Map<String, dynamic>>({
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      });
      final raw = result.data['profiles'];
      final profiles = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];
      final rawCursor = result.data['nextCursor'];
      final nextCursor =
          rawCursor is String && rawCursor.isNotEmpty ? rawCursor : null;
      final hasMore = result.data['hasMore'] == true && nextCursor != null;
      return DiscoverPage(
        profiles: profiles,
        nextCursor: nextCursor,
        hasMore: hasMore,
      );
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final reason = details is Map ? details['reason'] : null;
      if (error.code == 'failed-precondition' &&
          reason == 'discover-location-required') {
        throw const DiscoverLocationRequiredException();
      }
      if (error.code == 'failed-precondition' &&
          reason == 'discover-session-expired') {
        throw const DiscoverSessionExpiredException();
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
