import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

class ProfileMediaUpload {
  const ProfileMediaUpload({
    required this.photoId,
    required this.uploadUrl,
    required this.requiredContentType,
  });

  final String photoId;
  final Uri uploadUrl;
  final String requiredContentType;
}

class ProfileMediaStatus {
  const ProfileMediaStatus({
    required this.photoId,
    required this.status,
    required this.contentType,
    this.createdAt,
    this.processedAt,
    this.reviewedAt,
  });

  final String photoId;
  final String status;
  final String contentType;
  final DateTime? createdAt;
  final DateTime? processedAt;
  final DateTime? reviewedAt;

  factory ProfileMediaStatus.fromMap(Map<String, dynamic> data) {
    DateTime? dateFromMillis(Object? raw) {
      final value = raw is num ? raw.toInt() : null;
      return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
    }

    final photoId = data['photoId'] as String?;
    if (photoId == null || photoId.isEmpty) {
      throw StateError('Profile photo status was missing its photoId.');
    }
    return ProfileMediaStatus(
      photoId: photoId,
      status: data['status'] as String? ?? 'unknown',
      contentType: data['contentType'] as String? ?? '',
      createdAt: dateFromMillis(data['createdAtMs']),
      processedAt: dateFromMillis(data['processedAtMs']),
      reviewedAt: dateFromMillis(data['reviewedAtMs']),
    );
  }
}

class VisibleProfilePhoto {
  const VisibleProfilePhoto({
    required this.photoId,
    required this.url,
    this.createdAt,
  });

  final String photoId;
  final Uri url;
  final DateTime? createdAt;

  factory VisibleProfilePhoto.fromMap(Map<String, dynamic> data) {
    final photoId = data['photoId'] as String?;
    final rawUrl = data['url'] as String?;
    if (photoId == null || photoId.isEmpty || rawUrl == null || rawUrl.isEmpty) {
      throw StateError('Visible profile photo response was incomplete.');
    }
    final createdAtMs = data['createdAtMs'] is num
        ? (data['createdAtMs'] as num).toInt()
        : null;
    return VisibleProfilePhoto(
      photoId: photoId,
      url: Uri.parse(rawUrl),
      createdAt: createdAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    );
  }
}

class ProfileMediaService {
  ProfileMediaService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<ProfileMediaUpload> beginUpload(String contentType) async {
    final callable = _functions.httpsCallable('beginProfilePhotoUpload');
    final result = await callable.call<Map<String, dynamic>>({
      'contentType': contentType,
    });
    final data = result.data;
    final photoId = data['photoId'] as String?;
    final uploadUrl = data['uploadUrl'] as String?;
    final requiredContentType = data['requiredContentType'] as String?;
    if (photoId == null || uploadUrl == null || requiredContentType == null) {
      throw StateError('Profile photo upload authorization was incomplete.');
    }
    return ProfileMediaUpload(
      photoId: photoId,
      uploadUrl: Uri.parse(uploadUrl),
      requiredContentType: requiredContentType,
    );
  }

  Future<void> uploadBytes({
    required ProfileMediaUpload authorization,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('Photo is empty.');
    if (bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('Photo must be 10 MB or smaller.');
    }

    final client = HttpClient();
    try {
      final request = await client.putUrl(authorization.uploadUrl);
      request.headers.contentType = ContentType.parse(authorization.requiredContentType);
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Profile photo upload failed (${response.statusCode}).');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<String> confirmUpload(String photoId) async {
    final callable = _functions.httpsCallable('confirmProfilePhotoUpload');
    final result = await callable.call<Map<String, dynamic>>({'photoId': photoId});
    return result.data['status'] as String? ?? 'pending_processing';
  }

  Future<List<ProfileMediaStatus>> listMyPhotos() async {
    final callable = _functions.httpsCallable('listMyProfilePhotos');
    final result = await callable.call<Map<String, dynamic>>();
    final raw = result.data['photos'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => ProfileMediaStatus.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<VisibleProfilePhoto>> listVisiblePhotos(String ownerUid) async {
    final callable = _functions.httpsCallable('listMyProfilePhotos');
    final result = await callable.call<Map<String, dynamic>>({'ownerUid': ownerUid});
    final raw = result.data['photos'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => VisibleProfilePhoto.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<Uri> getAccessUrl(String photoId) async {
    final callable = _functions.httpsCallable('getProfilePhotoAccess');
    final result = await callable.call<Map<String, dynamic>>({'photoId': photoId});
    final url = result.data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('Profile photo access response was incomplete.');
    }
    return Uri.parse(url);
  }

  Future<void> deletePhoto(String photoId) async {
    final callable = _functions.httpsCallable('deleteProfilePhoto');
    final result = await callable.call<Map<String, dynamic>>({'photoId': photoId});
    if (result.data['deleted'] != true) {
      throw StateError('Profile photo was not deleted.');
    }
  }
}
