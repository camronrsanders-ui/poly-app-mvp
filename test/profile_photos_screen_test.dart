import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/profile/profile_photos_screen.dart';
import 'package:polycircle/services/profile_media_service.dart';

ProfileMediaStatus photoStatus(String photoId, String status) {
  return ProfileMediaStatus(
    photoId: photoId,
    status: status,
    contentType: 'image/jpeg',
  );
}

Future<Uri> unusedAccess(String photoId) async {
  return Uri.parse('https://example.test/$photoId');
}

Future<void> unusedDelete(String photoId) async {}

Future<void> pumpPhotos(
  WidgetTester tester, {
  required ProfilePhotosLoader loadPhotos,
  ProfilePhotoAccessLoader? getAccessUrl,
  ProfilePhotoDeleteAction? deletePhoto,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProfilePhotosScreen.test(
        loadPhotos: loadPhotos,
        getAccessUrl: getAccessUrl ?? unusedAccess,
        deletePhoto: deletePhoto ?? unusedDelete,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollTo(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> openDeleteDialog(WidgetTester tester) async {
  final popup = find.byType(PopupMenuButton<String>).first;
  await scrollTo(tester, popup);

  await tester.tap(popup);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Delete').last);
  await tester.pumpAndSettle();

  expect(find.text('Delete this photo?'), findsOneWidget);
  expect(
    find.textContaining('This removes the photo from Polycircle.'),
    findsOneWidget,
  );
  expect(
    find.textContaining('This action cannot be undone.'),
    findsOneWidget,
  );
}

Finder menuForStatus(String statusLabel) {
  final tile = find.ancestor(
    of: find.text(statusLabel),
    matching: find.byType(ListTile),
  );
  return find.descendant(
    of: tile,
    matching: find.byType(PopupMenuButton<String>),
  );
}

void main() {
  testWidgets(
    'Empty profile photos explains quarantine review and Private Vault separation',
    (tester) async {
      await pumpPhotos(
        tester,
        loadPhotos: () async => const [],
      );

      expect(find.text('Protected profile photos'), findsOneWidget);
      expect(
        find.textContaining(
          'Uploads go to a private quarantine area first.',
        ),
        findsOneWidget,
      );
      expect(find.text('No profile photos yet'), findsOneWidget);
      expect(
        find.textContaining(
          'Nothing is made visible until processing and review are complete.',
        ),
        findsOneWidget,
      );

      final vaultCopy = find.textContaining(
        'Profile photos are separate from the Private Vault.',
      );
      await scrollTo(tester, vaultCopy);
      expect(vaultCopy, findsOneWidget);
    },
  );

  testWidgets(
    'Profile photo statuses preserve processing and moderation meaning',
    (tester) async {
      final photos = <ProfileMediaStatus>[
        photoStatus('photo-pending-001', 'pending_processing'),
        photoStatus('photo-review-001', 'processed_pending_review'),
        photoStatus('photo-active-001', 'active'),
        photoStatus('photo-rejected-001', 'rejected'),
        photoStatus('photo-unknown-001', 'unexpected_status'),
      ];

      await pumpPhotos(
        tester,
        loadPhotos: () async => photos,
      );

      for (final label in <String>[
        'Processing securely',
        'Awaiting safety review',
        'Visible on your profile',
        'Not approved',
        'Status unavailable',
      ]) {
        final finder = find.text(label);
        await scrollTo(tester, finder);
        expect(finder, findsOneWidget);
      }
    },
  );

  testWidgets(
    'Deleting a profile photo requires explicit confirmation',
    (tester) async {
      var deleteCalls = 0;
      final photo = photoStatus('photo-cancel-001', 'active');

      await pumpPhotos(
        tester,
        loadPhotos: () async => [photo],
        deletePhoto: (photoId) async {
          deleteCalls += 1;
        },
      );

      await openDeleteDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deleteCalls, 0);
      expect(find.text('Visible on your profile'), findsOneWidget);
    },
  );

  testWidgets(
    'Successful profile photo delete reloads and reports success',
    (tester) async {
      var deleteCalls = 0;
      var loadCalls = 0;
      var deleted = false;
      String? deletedPhotoId;

      final photo = photoStatus('photo-delete-001', 'active');

      await pumpPhotos(
        tester,
        loadPhotos: () async {
          loadCalls += 1;
          return deleted ? const [] : [photo];
        },
        deletePhoto: (photoId) async {
          deleteCalls += 1;
          deletedPhotoId = photoId;
          deleted = true;
        },
      );

      expect(loadCalls, 1);

      await openDeleteDialog(tester);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(deleteCalls, 1);
      expect(deletedPhotoId, 'photo-delete-001');
      expect(loadCalls, 2);
      expect(find.text('No profile photos yet'), findsOneWidget);
      expect(find.text('Profile photo deleted.'), findsOneWidget);
    },
  );

  testWidgets(
    'Failed profile photo delete is truthful and recoverable',
    (tester) async {
      var attempts = 0;
      var deleted = false;
      final photo = photoStatus('photo-retry-001', 'active');

      await pumpPhotos(
        tester,
        loadPhotos: () async => deleted ? const [] : [photo],
        deletePhoto: (photoId) async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('temporary failure');
          }
          deleted = true;
        },
      );

      await openDeleteDialog(tester);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(
        find.text('Could not delete this photo right now.'),
        findsOneWidget,
      );
      expect(find.text('Profile photo deleted.'), findsNothing);
      expect(find.text('Visible on your profile'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await openDeleteDialog(tester);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text('No profile photos yet'), findsOneWidget);
      expect(find.text('Profile photo deleted.'), findsOneWidget);
    },
  );

  testWidgets(
    'Pending profile photo delete blocks duplicate submission and recovers',
    (tester) async {
      final pendingDelete = Completer<void>();
      var deleteCalls = 0;
      final photo = photoStatus('photo-pending-delete-001', 'active');

      await pumpPhotos(
        tester,
        loadPhotos: () async => [photo],
        deletePhoto: (photoId) {
          deleteCalls += 1;
          return pendingDelete.future;
        },
      );

      await openDeleteDialog(tester);
      await tester.tap(find.text('Delete').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(deleteCalls, 1);

      var popup = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>).first,
      );
      expect(popup.enabled, isFalse);

      await tester.tap(
        find.byType(PopupMenuButton<String>).first,
        warnIfMissed: false,
      );
      await tester.pump();

      expect(deleteCalls, 1);
      expect(find.text('Delete this photo?'), findsNothing);

      pendingDelete.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await scrollTo(
        tester,
        find.byType(PopupMenuButton<String>).first,
      );

      popup = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>).first,
      );
      expect(popup.enabled, isTrue);
      expect(deleteCalls, 1);
    },
  );

  testWidgets(
    'Profile photo load failure reports a truthful error',
    (tester) async {
      await pumpPhotos(
        tester,
        loadPhotos: () async {
          throw StateError('load failure');
        },
      );

      expect(
        find.text('Could not load profile photos right now.'),
        findsOneWidget,
      );
      expect(find.text('Visible on your profile'), findsNothing);
    },
  );

  testWidgets(
    'Only active photos expose secure viewing',
    (tester) async {
      final photos = <ProfileMediaStatus>[
        photoStatus('photo-processing-001', 'pending_processing'),
        photoStatus('photo-active-view-001', 'active'),
      ];

      await pumpPhotos(
        tester,
        loadPhotos: () async => photos,
      );

      final processingLabel = find.text('Processing securely');
      await scrollTo(tester, processingLabel);

      final processingMenu = menuForStatus('Processing securely');
      await tester.tap(processingMenu);
      await tester.pumpAndSettle();

      expect(find.text('View securely'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      final activeLabel = find.text('Visible on your profile');
      await scrollTo(tester, activeLabel);

      final activeMenu = menuForStatus('Visible on your profile');
      await tester.tap(activeMenu);
      await tester.pumpAndSettle();

      expect(find.text('View securely'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    },
  );
}
