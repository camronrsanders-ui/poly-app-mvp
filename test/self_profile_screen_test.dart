import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/profile/self_profile_screen.dart';
import 'package:polycircle/services/profile_media_service.dart';

Map<String, dynamic> profile({
  String profileVisibility = 'public',
  String mapVisibility = 'public',
}) =>
    <String, dynamic>{
      'displayName': 'Cam',
      'age': 30,
      'city': 'Somerville',
      'region': 'MA',
      'headline': 'Community first',
      'bio': 'Building thoughtful connections.',
      'pronouns': 'he/him',
      'genderIdentity': 'Man',
      'orientation': 'Gay',
      'relationshipStructure': 'Solo poly',
      'relationshipStatus': 'Open',
      'lookingForNote': 'Friendship and dating',
      'customIdentityTags': <String>['Queer'],
      'intentionTags': <String>['Friendship', 'Dating'],
      'interests': <String>['Kickball'],
      'profileVisibility': profileVisibility,
      'mapVisibility': mapVisibility,
    };

ProfileMediaStatus activePhoto(String id) {
  return ProfileMediaStatus(
    photoId: id,
    status: 'active',
    contentType: 'image/jpeg',
  );
}

Future<void> pumpSelfProfile(
  WidgetTester tester, {
  required SelfProfileLoader loadProfile,
  SelfProfilePhotosLoader? loadPhotos,
  SelfProfilePhotoAccessLoader? getPhotoAccess,
  SelfProfileCircleLoader? loadCircle,
  SelfProfileAction? editProfileAction,
  SelfProfileAction? managePhotosAction,
  SelfProfileAction? signOutAction,
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SelfProfileScreen(
          uidProvider: () => 'member-1',
          loadProfile: loadProfile,
          loadPhotos: loadPhotos ?? () async => const [],
          getPhotoAccess: getPhotoAccess,
          loadCircle: loadCircle ?? (uid) async => const [],
          editProfileAction: editProfileAction,
          managePhotosAction: managePhotosAction,
          signOutAction: signOutAction,
        ),
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

void main() {
  testWidgets(
    'Profile preview load failure exposes a working retry',
    (tester) async {
      var loads = 0;

      await pumpSelfProfile(
        tester,
        loadProfile: (uid) async {
          loads += 1;
          if (loads == 1) {
            throw StateError('temporary failure');
          }
          return profile();
        },
      );

      expect(
        find.text('Could not load your profile preview'),
        findsOneWidget,
      );

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(loads, 2);
      expect(find.text('Cam, 30'), findsOneWidget);
    },
  );

  testWidgets(
    'Pull to refresh requests fresh profile data',
    (tester) async {
      var loads = 0;

      await pumpSelfProfile(
        tester,
        loadProfile: (uid) async {
          loads += 1;
          return profile();
        },
      );

      expect(loads, 1);

      await tester.drag(
        find.byType(ListView).first,
        const Offset(0, 500),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(loads, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'Connection preview reveals only allowed Circle cards',
    (tester) async {
      final cards = <Map<String, dynamic>>[
        <String, dynamic>{
          'label': 'Friend',
          'displayNameOptional': 'Alex',
          'visibility': 'public',
          'sortOrder': 1,
        },
        <String, dynamic>{
          'label': 'Partner',
          'displayNameOptional': 'Bailey',
          'visibility': 'matches_only',
          'sortOrder': 2,
        },
        <String, dynamic>{
          'label': 'Private person',
          'displayNameOptional': 'Devon',
          'visibility': 'private',
          'sortOrder': 3,
        },
        <String, dynamic>{
          'label': 'Roommate',
          'displayNameOptional': 'Casey',
          'note': 'Private note',
          'visibility': 'unnamed_public',
          'sortOrder': 4,
        },
      ];

      await pumpSelfProfile(
        tester,
        loadProfile: (uid) async {
          return profile(mapVisibility: 'matches_only');
        },
        loadCircle: (uid) async => cards,
      );

      await scrollTo(
        tester,
        find.text('Your Circle is shared with connections only.'),
      );
      expect(find.text('Friend · Alex'), findsNothing);

      await scrollTo(tester, find.text('Connection'));
      await tester.tap(find.text('Connection'));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Friend · Alex'));
      expect(find.text('Friend · Alex'), findsOneWidget);
      expect(find.text('Partner · Bailey'), findsOneWidget);
      expect(find.text('Private person · Devon'), findsNothing);
      expect(find.text('Roommate'), findsOneWidget);
      expect(find.text('Roommate · Casey'), findsNothing);
      expect(find.text('Private note'), findsNothing);
    },
  );

  testWidgets(
    'Edit and Photos actions reload the preview after returning',
    (tester) async {
      var loads = 0;
      var edits = 0;
      var photos = 0;

      await pumpSelfProfile(
        tester,
        loadProfile: (uid) async {
          loads += 1;
          return profile();
        },
        editProfileAction: () async {
          edits += 1;
        },
        managePhotosAction: () async {
          photos += 1;
        },
      );

      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      expect(edits, 1);
      expect(loads, 2);

      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();

      expect(photos, 1);
      expect(loads, 3);
    },
  );

  testWidgets(
    'Log out uses the supplied session action',
    (tester) async {
      var signOuts = 0;

      await pumpSelfProfile(
        tester,
        loadProfile: (uid) async => profile(),
        signOutAction: () async {
          signOuts += 1;
        },
      );

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(signOuts, 1);
    },
  );

  testWidgets(
    'Circle load failure leaves the main profile usable',
    (tester) async {
      await pumpSelfProfile(
        tester,
        loadProfile: (uid) async => profile(),
        loadCircle: (uid) async {
          throw StateError('circle unavailable');
        },
      );

      expect(find.text('Cam, 30'), findsOneWidget);

      await scrollTo(
        tester,
        find.text('No Circle details are shared with this audience.'),
      );
      expect(
        find.text('No Circle details are shared with this audience.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Approved photo access failure stays truthful and recoverable',
    (tester) async {
      var accessCalls = 0;

      await pumpSelfProfile(
        tester,
        loadProfile: (uid) async => profile(),
        loadPhotos: () async => <ProfileMediaStatus>[
          activePhoto('photo-1'),
        ],
        getPhotoAccess: (photoId) async {
          accessCalls += 1;
          throw StateError('temporary access failure');
        },
      );

      expect(accessCalls, 3);
      expect(
        find.textContaining(
          'approved profile photo is temporarily unavailable',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Pull down to refresh'),
        findsOneWidget,
      );
    },
  );
}
