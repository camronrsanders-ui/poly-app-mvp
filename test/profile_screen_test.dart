import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/profile/profile_screen.dart';

Map<String, dynamic> profileData() => <String, dynamic>{
      'displayName': 'Cam',
      'age': 30,
      'city': 'Somerville',
      'region': 'MA',
      'bio': 'Hello',
      'headline': 'Open connections',
      'genderIdentity': 'Man',
      'pronouns': 'he/him',
      'orientation': 'Gay',
      'relationshipStructure': 'Polyamorous',
      'relationshipStatus': 'Partnered',
      'partnered': true,
      'lookingForNote': 'Community',
      'interests': <String>['anime', 'kickball'],
      'openToConnections': true,
      'profileVisibility': 'public',
      'mapVisibility': 'matches_only',
      'intentionTags': <String>[],
      'ageMin': 25,
      'ageMax': 45,
      'distanceRadius': 25,
      'preferredStructures': <String>[],
      'preferredIntentions': <String>[],
    };

Future<void> noopAction() async {}

Future<void> pumpProfile(
  WidgetTester tester, {
  required ProfileEditorLoader loadProfile,
  ProfileEditorSaver? saveProfile,
  ProfileEditorAction? managePhotosAction,
  ProfileEditorAction? signOutAction,
  ProfileEditorAction? deleteAccountAction,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProfileScreen.test(
          currentUid: 'member-1',
          loadProfile: loadProfile,
          saveProfile: saveProfile ?? (uid, values) async {},
          managePhotosAction: managePhotosAction ?? noopAction,
          signOutAction: signOutAction ?? noopAction,
          deleteAccountAction: deleteAccountAction ?? noopAction,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Profile load failure exposes a working retry',
    (tester) async {
      var calls = 0;

      await pumpProfile(
        tester,
        loadProfile: (uid) async {
          calls += 1;
          if (calls == 1) throw StateError('temporary load failure');
          return profileData();
        },
      );

      expect(find.text('Could not load your profile'), findsOneWidget);
      expect(calls, 1);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.text('Your profile'), findsOneWidget);
      expect(find.text('Could not load your profile'), findsNothing);
    },
  );

  testWidgets(
    'Save profile sends normalized edited values through the trusted action',
    (tester) async {
      String? savedUid;
      Map<String, dynamic>? savedValues;

      await pumpProfile(
        tester,
        loadProfile: (uid) async => profileData(),
        saveProfile: (uid, values) async {
          savedUid = uid;
          savedValues = Map<String, dynamic>.from(values);
        },
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        '  Cam Updated  ',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Interests (comma separated)'),
        'anime, kickball, anime, photography',
      );

      final save = find.text('Save profile');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(savedUid, 'member-1');
      expect(savedValues?['displayName'], 'Cam Updated');
      expect(
        savedValues?['interests'],
        <String>['anime', 'kickball', 'photography'],
      );
      expect(savedValues?['age'], 30);
      expect(find.text('Profile updated.'), findsOneWidget);
    },
  );

  testWidgets(
    'Invalid profile values never invoke save',
    (tester) async {
      var saves = 0;

      await pumpProfile(
        tester,
        loadProfile: (uid) async => profileData(),
        saveProfile: (uid, values) async {
          saves += 1;
        },
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        '   ',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Age'),
        '17',
      );

      final save = find.text('Save profile');
      await scrollTo(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(saves, 0);
      expect(
        find.text('Enter a display name and a valid age from 18 to 120.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Profile photo and logout buttons invoke their actions',
    (tester) async {
      var photoCalls = 0;
      var logoutCalls = 0;

      await pumpProfile(
        tester,
        loadProfile: (uid) async => profileData(),
        managePhotosAction: () async {
          photoCalls += 1;
        },
        signOutAction: () async {
          logoutCalls += 1;
        },
      );

      await tester.tap(find.text('Manage profile photos'));
      await tester.pumpAndSettle();
      expect(photoCalls, 1);

      final logout = find.text('Log out');
      await scrollTo(tester, logout);
      await tester.tap(logout);
      await tester.pumpAndSettle();
      expect(logoutCalls, 1);
    },
  );

  testWidgets(
    'Delete my account reaches the injected delete action only after DELETE',
    (tester) async {
      var deletes = 0;

      await pumpProfile(
        tester,
        loadProfile: (uid) async => profileData(),
        deleteAccountAction: () async {
          deletes += 1;
        },
      );

      final deleteButton = find.text('Delete my account');
      await scrollTo(tester, deleteButton);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'DELETE');
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      expect(deletes, 1);
    },
  );
}
