import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/services/profile_media_service.dart';

void main() {
  const maxSupportedEpochMillis = 253402300799999;

  test('ProfileMediaStatus accepts trusted integer epoch milliseconds', () {
    final status = ProfileMediaStatus.fromMap(
      <String, dynamic>{
        'photoId': 'photo-1',
        'status': 'active',
        'contentType': 'image/jpeg',
        'createdAtMs': 0,
        'processedAtMs': 1700000000000,
        'reviewedAtMs': maxSupportedEpochMillis,
      },
    );

    expect(status.createdAt?.millisecondsSinceEpoch, 0);
    expect(status.processedAt?.millisecondsSinceEpoch, 1700000000000);
    expect(
      status.reviewedAt?.millisecondsSinceEpoch,
      maxSupportedEpochMillis,
    );
  });

  test('ProfileMediaStatus fails closed for malformed timestamps', () {
    final invalidValues = <Object?>[
      -1,
      maxSupportedEpochMillis + 1,
      123.5,
      double.nan,
      double.infinity,
      double.negativeInfinity,
      '123',
      null,
    ];

    for (final value in invalidValues) {
      final status = ProfileMediaStatus.fromMap(
        <String, dynamic>{
          'photoId': 'photo-1',
          'status': 'active',
          'contentType': 'image/jpeg',
          'createdAtMs': value,
          'processedAtMs': value,
          'reviewedAtMs': value,
        },
      );

      expect(status.createdAt, isNull, reason: 'createdAtMs: $value');
      expect(status.processedAt, isNull, reason: 'processedAtMs: $value');
      expect(status.reviewedAt, isNull, reason: 'reviewedAtMs: $value');
    }
  });

  test('VisibleProfilePhoto accepts trusted integer epoch milliseconds', () {
    final photo = VisibleProfilePhoto.fromMap(
      <String, dynamic>{
        'photoId': 'photo-1',
        'url': 'https://example.com/photo.jpg',
        'createdAtMs': maxSupportedEpochMillis,
      },
    );

    expect(
      photo.createdAt?.millisecondsSinceEpoch,
      maxSupportedEpochMillis,
    );
  });

  test('VisibleProfilePhoto fails closed for malformed timestamps', () {
    final invalidValues = <Object?>[
      -1,
      maxSupportedEpochMillis + 1,
      123.5,
      double.nan,
      double.infinity,
      double.negativeInfinity,
      '123',
      null,
    ];

    for (final value in invalidValues) {
      final photo = VisibleProfilePhoto.fromMap(
        <String, dynamic>{
          'photoId': 'photo-1',
          'url': 'https://example.com/photo.jpg',
          'createdAtMs': value,
        },
      );

      expect(photo.createdAt, isNull, reason: 'createdAtMs: $value');
    }
  });

  test('required profile media identifiers remain enforced', () {
    expect(
      () => ProfileMediaStatus.fromMap(
        <String, dynamic>{
          'status': 'active',
          'contentType': 'image/jpeg',
        },
      ),
      throwsStateError,
    );

    expect(
      () => VisibleProfilePhoto.fromMap(
        <String, dynamic>{
          'photoId': 'photo-1',
          'createdAtMs': 0,
        },
      ),
      throwsStateError,
    );
  });
}
