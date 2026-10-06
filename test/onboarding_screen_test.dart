import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/onboarding/onboarding_screen.dart';

Future<void> pumpOnboarding(
  WidgetTester tester, {
  required VoidCallback onComplete,
  OnboardingSaveProfile? saveProfile,
  OnboardingCompleteProfile? completeOnboarding,
}) async {
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: OnboardingScreen(
        onComplete: onComplete,
        uidProvider: () => 'member-1',
        saveProfile: saveProfile,
        completeOnboarding: completeOnboarding,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> tapContinue(WidgetTester tester) async {
  await tester.tap(
    find.widgetWithText(FilledButton, 'Continue'),
  );
  await tester.pumpAndSettle();
}

Future<void> tapBack(WidgetTester tester) async {
  await tester.tap(
    find.widgetWithText(TextButton, 'Back'),
  );
  await tester.pumpAndSettle();
}

Future<void> reachStructureStep(WidgetTester tester) async {
  await tapContinue(tester);
  await tapContinue(tester);
}

Future<void> reachIntentionsStep(WidgetTester tester) async {
  await reachStructureStep(tester);
  await tester.tap(
    find.widgetWithText(ChoiceChip, 'Solo poly'),
  );
  await tester.pumpAndSettle();
  await tapContinue(tester);
}

Future<void> reachFinalStep(
  WidgetTester tester, {
  required String name,
  required String age,
}) async {
  await tester.enterText(field('Display name'), name);
  await tester.enterText(field('Age (18+)'), age);
  await reachIntentionsStep(tester);
  await tester.tap(
    find.widgetWithText(FilterChip, 'Friendship'),
  );
  await tester.pumpAndSettle();
  await tapContinue(tester);
}

Future<void> tapEnter(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await tester.tap(
    find.widgetWithText(FilledButton, 'Enter Polycircle'),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'Continue and Back preserve typed answers',
    (tester) async {
      await pumpOnboarding(
        tester,
        onComplete: () {},
      );

      await tester.enterText(field('Display name'), 'Cam');
      await tester.enterText(field('Age (18+)'), '30');
      await tapContinue(tester);

      expect(find.text('How do you identify?'), findsOneWidget);

      await tapBack(tester);

      expect(find.text('Start with you'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Display name')).controller?.text,
        'Cam',
      );
      expect(
        tester.widget<TextField>(field('Age (18+)')).controller?.text,
        '30',
      );
    },
  );

  testWidgets(
    'Final submit requires core onboarding answers',
    (tester) async {
      var saves = 0;

      await pumpOnboarding(
        tester,
        onComplete: () {},
        saveProfile: (uid, values) async {
          saves += 1;
        },
      );

      for (var index = 0; index < 4; index += 1) {
        await tapContinue(tester);
      }
      await tapEnter(tester);

      expect(
        find.textContaining('Please complete your name, age'),
        findsOneWidget,
      );
      expect(saves, 0);
    },
  );

  testWidgets(
    'Under-18 age is blocked before persistence',
    (tester) async {
      var saves = 0;

      await pumpOnboarding(
        tester,
        onComplete: () {},
        saveProfile: (uid, values) async {
          saves += 1;
        },
      );

      await reachFinalStep(
        tester,
        name: 'Cam',
        age: '17',
      );
      await tapEnter(tester);

      expect(
        find.text('Polycircle is for adults age 18 and older.'),
        findsOneWidget,
      );
      expect(saves, 0);
    },
  );

  testWidgets(
    'Age above 120 is rejected before persistence',
    (tester) async {
      var saves = 0;

      await pumpOnboarding(
        tester,
        onComplete: () {},
        saveProfile: (uid, values) async {
          saves += 1;
        },
      );

      await reachFinalStep(
        tester,
        name: 'Cam',
        age: '121',
      );
      await tapEnter(tester);

      expect(find.text('Please enter a valid age.'), findsOneWidget);
      expect(saves, 0);
    },
  );

  testWidgets(
    'Successful onboarding persists exact profile choices in order',
    (tester) async {
      Map<String, dynamic>? savedValues;
      final calls = <String>[];

      await pumpOnboarding(
        tester,
        onComplete: () {
          calls.add('callback');
        },
        saveProfile: (uid, values) async {
          calls.add('save:$uid');
          savedValues = Map<String, dynamic>.from(values);
        },
        completeOnboarding: (uid) async {
          calls.add('complete:$uid');
        },
      );

      await tester.enterText(field('Display name'), ' Cam ');
      await tester.enterText(field('Age (18+)'), '30');
      await tester.enterText(field('City'), 'Somerville');
      await tester.enterText(field('State / region'), 'MA');
      await tapContinue(tester);

      await tester.enterText(field('Gender identity'), 'Man');
      await tester.enterText(field('Pronouns'), 'he/him');
      await tester.enterText(field('Orientation'), 'Gay');
      await tapContinue(tester);

      await tester.tap(
        find.widgetWithText(ChoiceChip, 'Solo poly'),
      );
      await tester.pumpAndSettle();
      await tapContinue(tester);

      await tester.tap(
        find.widgetWithText(FilterChip, 'Friendship'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilterChip, 'Dating'),
      );
      await tester.pumpAndSettle();
      await tapContinue(tester);

      await tester.enterText(field('About me'), 'Community-minded.');
      await tester.enterText(
        field('What are you looking for?'),
        'Good connections.',
      );
      await tapEnter(tester);

      expect(calls, <String>[
        'save:member-1',
        'complete:member-1',
        'callback',
      ]);
      expect(savedValues?['displayName'], 'Cam');
      expect(savedValues?['age'], 30);
      expect(savedValues?['city'], 'Somerville');
      expect(savedValues?['region'], 'MA');
      expect(savedValues?['genderIdentity'], 'Man');
      expect(savedValues?['pronouns'], 'he/him');
      expect(savedValues?['orientation'], 'Gay');
      expect(savedValues?['relationshipStructure'], 'Solo poly');
      expect(
        savedValues?['intentionTags'],
        containsAll(<String>['Friendship', 'Dating']),
      );
      expect(savedValues?['bio'], 'Community-minded.');
      expect(savedValues?['lookingForNote'], 'Good connections.');
      expect(savedValues?['distanceRadius'], 20);
      expect(savedValues?['profileVisibility'], 'public');
      expect(savedValues?['mapVisibility'], 'matches_only');
    },
  );

  testWidgets(
    'Failed save preserves answers and allows retry',
    (tester) async {
      var attempts = 0;
      var completions = 0;

      await pumpOnboarding(
        tester,
        onComplete: () {
          completions += 1;
        },
        saveProfile: (uid, values) async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('temporary failure');
          }
        },
        completeOnboarding: (uid) async {},
      );

      await reachFinalStep(
        tester,
        name: 'Cam',
        age: '30',
      );
      await tester.enterText(field('About me'), 'Keep this answer.');
      await tapEnter(tester);

      expect(
        find.textContaining('Your answers are still here'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field('About me')).controller?.text,
        'Keep this answer.',
      );
      expect(completions, 0);

      await tapEnter(tester);

      expect(attempts, 2);
      expect(completions, 1);
    },
  );

  testWidgets(
    'Pending save disables duplicate onboarding submission',
    (tester) async {
      final gate = Completer<void>();
      var saves = 0;

      await pumpOnboarding(
        tester,
        onComplete: () {},
        saveProfile: (uid, values) {
          saves += 1;
          return gate.future;
        },
        completeOnboarding: (uid) async {},
      );

      await reachFinalStep(
        tester,
        name: 'Cam',
        age: '30',
      );
      await tapEnter(
        tester,
        settle: false,
      );

      final saving = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Saving…'),
      );
      expect(saving.onPressed, isNull);
      expect(saves, 1);

      gate.complete();
      await tester.pumpAndSettle();

      expect(saves, 1);
    },
  );
}
