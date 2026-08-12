import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_runtime.dart';

class ModerationProfilePhoto {
  const ModerationProfilePhoto({
    required this.photoId,
    required this.ownerUid,
    required this.ownerDisplayName,
    this.previewBytes,
    this.previewUrl,
  });

  final String photoId;
  final String ownerUid;
  final String ownerDisplayName;
  final Uint8List? previewBytes;
  final Uri? previewUrl;

  factory ModerationProfilePhoto.fromMap(Map<String, dynamic> data) {
    final photoId = data['photoId']?.toString() ?? '';
    final ownerUid = data['ownerUid']?.toString() ?? '';
    final ownerDisplayName = data['ownerDisplayName']?.toString().trim() ?? '';
    if (photoId.isEmpty || ownerUid.isEmpty) {
      throw StateError('Moderation photo response was incomplete.');
    }

    Uint8List? previewBytes;
    final encoded = data['previewBytesBase64'];
    if (encoded is String && encoded.isNotEmpty) {
      previewBytes = base64Decode(encoded);
    }
    final rawUrl = data['previewUrl'];
    final previewUrl = rawUrl is String && rawUrl.isNotEmpty ? Uri.parse(rawUrl) : null;
    if (previewBytes == null && previewUrl == null) {
      throw StateError('Moderation photo preview was missing.');
    }

    return ModerationProfilePhoto(
      photoId: photoId,
      ownerUid: ownerUid,
      ownerDisplayName: ownerDisplayName.isEmpty ? 'Member' : ownerDisplayName,
      previewBytes: previewBytes,
      previewUrl: previewUrl,
    );
  }
}

class ProfilePhotoModerationService {
  ProfilePhotoModerationService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<bool> hasLocalModeratorAccess({bool forceRefresh = false}) async {
    if (!kDebugMode || !useFirebaseEmulators) return false;
    final user = _auth.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(forceRefresh);
    final claims = token.claims ?? const <String, dynamic>{};
    return claims['moderator'] == true ||
        claims['admin'] == true ||
        claims['superadmin'] == true;
  }

  Future<void> _requireLocalModerator() async {
    if (!await hasLocalModeratorAccess()) {
      throw StateError('Local moderator QA access is unavailable.');
    }
  }

  Future<List<ModerationProfilePhoto>> listPending({int limit = 30}) async {
    await _requireLocalModerator();
    final callable = _functions.httpsCallable('listProfilePhotosForReview');
    final result = await callable.call<Map<String, dynamic>>({'limit': limit});
    final raw = result.data['photos'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => ModerationProfilePhoto.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<String> review({
    required String photoId,
    required String decision,
    String? reason,
  }) async {
    await _requireLocalModerator();
    if (decision != 'approve' && decision != 'reject') {
      throw ArgumentError.value(decision, 'decision', 'Must be approve or reject.');
    }
    final callable = _functions.httpsCallable('reviewProfilePhoto');
    final result = await callable.call<Map<String, dynamic>>({
      'photoId': photoId,
      'decision': decision,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    final status = result.data['status']?.toString() ?? '';
    if (status != 'active' && status != 'rejected') {
      throw StateError('Moderation review returned an unexpected status.');
    }
    return status;
  }
}
