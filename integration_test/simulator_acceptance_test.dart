import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:polycircle/main.dart' as app;

const bool _captureAcceptanceScreenshots = bool.fromEnvironment(
  'POLYCIRCLE_CAPTURE_ACCEPTANCE_SCREENSHOTS',
  defaultValue: true,
);

Future<void> waitForFinder(
  WidgetTester tester,
  Finder finder, {
  String? description,
  int maxPumps = 160,
}) async {
  for (var attempt = 0; attempt < maxPumps; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }

  throw TestFailure(
    'Timed out waiting for ${description ?? finder.toString()}.',
  );
}

Future<Finder> waitForAny(
  WidgetTester tester,
  List<Finder> finders, {
  int maxPumps = 160,
}) async {
  for (var attempt = 0; attempt < maxPumps; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 250));
    for (final finder in finders) {
      if (finder.evaluate().isNotEmpty) return finder;
    }
  }

  throw TestFailure('Timed out waiting for any expected route.');
}

Finder navLabel(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

Future<void> openNavTab(
  WidgetTester tester,
  String label,
) async {
  final destination = navLabel(label);
  await waitForFinder(
    tester,
    destination,
    description: '$label navigation destination',
  );
  await tester.tap(destination);
  await tester.pump();
}

Future<void> takeAcceptanceScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await tester.pump(const Duration(milliseconds: 300));
  debugPrint('POLYCIRCLE_ACCEPTANCE:$name');
  if (!_captureAcceptanceScreenshots) return;
  await binding.takeScreenshot(name);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'seeded device emulator completes the pre-billing core journey',
    (tester) async {
      await app.main();

      await waitForFinder(
        tester,
        find.text('Welcome back'),
        description: 'login screen',
      );
      await takeAcceptanceScreenshot(binding, tester, '01-login');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'cam@local.polycircle.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'LocalOnly123!',
      );

      final signIn = find.widgetWithText(FilledButton, 'Sign in');
      await tester.ensureVisible(signIn);
      await tester.tap(signIn);

      final route = await waitForAny(
        tester,
        <Finder>[
          find.text('Adult access & community rules'),
          find.text('Explore your orbit'),
        ],
      );

      if (route.evaluate().any(
            (element) =>
                element.widget is Text &&
                (element.widget as Text).data ==
                    'Adult access & community rules',
          )) {
        await takeAcceptanceScreenshot(binding, tester, '02-compliance');

        await tester.tap(find.text('Date of birth'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        final complianceScroll = find.byType(Scrollable).first;

        final termsTile = find.widgetWithText(
          CheckboxListTile,
          'I am 18+ and accept the Terms of Use',
        );
        await tester.scrollUntilVisible(
          termsTile,
          120,
          scrollable: complianceScroll,
        );
        await tester.ensureVisible(termsTile);
        await tester.pumpAndSettle();
        final termsCheckbox = find.descendant(
          of: termsTile,
          matching: find.byType(Checkbox),
        );
        await tester.tap(termsCheckbox);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(termsCheckbox).value, isTrue);

        final guidelinesTile = find.widgetWithText(
          CheckboxListTile,
          'I accept the Community Guidelines',
        );
        await tester.scrollUntilVisible(
          guidelinesTile,
          120,
          scrollable: complianceScroll,
        );
        await tester.ensureVisible(guidelinesTile);
        await tester.pumpAndSettle();
        final guidelinesCheckbox = find.descendant(
          of: guidelinesTile,
          matching: find.byType(Checkbox),
        );
        await tester.tap(guidelinesCheckbox);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(guidelinesCheckbox).value, isTrue);

        final verifyLabel = find.text('Verify & continue');
        await tester.scrollUntilVisible(
          verifyLabel,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(verifyLabel);
      }

      await waitForFinder(
        tester,
        find.text('Explore your orbit'),
        description: 'Discover world',
        maxPumps: 240,
      );
      await waitForFinder(
        tester,
        find.text('Connect'),
        description: 'Discover profile action',
        maxPumps: 240,
      );
      expect(find.text('Pass'), findsOneWidget);
      await takeAcceptanceScreenshot(binding, tester, '03-discover');

      // Live iOS/Android regression for the two-person Discover fixture:
      // moving to Riley then passing must update the count immediately.
      await waitForFinder(
        tester,
        find.text('1 / 2'),
        description: 'initial two-person Discover counter',
      );
      await tester.tap(
        find.byKey(const Key('discovery-next-profile')),
      );
      await waitForFinder(
        tester,
        find.text('2 / 2'),
        description: 'second Discover profile counter',
      );

      final passAction = find.byKey(const Key('discovery-pass'));
      await tester.drag(
        find.byKey(const Key('discover-world-scroll-view')),
        const Offset(0, -500),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.ensureVisible(passAction);
      await tester.tap(passAction);
      await waitForFinder(
        tester,
        find.text('1 / 1'),
        description: 'updated Discover counter immediately after Pass',
      );
      expect(find.text('2 / 2'), findsNothing);
      await takeAcceptanceScreenshot(
        binding,
        tester,
        '03a-discover-pass-counter',
      );

      await openNavTab(tester, 'Connections');
      await waitForFinder(
        tester,
        find.textContaining('Jordan'),
        description: 'seeded connection',
        maxPumps: 160,
      );
      await takeAcceptanceScreenshot(binding, tester, '04-connections');

      await openNavTab(tester, 'Circle');
      await waitForFinder(
        tester,
        find.text('Your relationship universe'),
        description: 'My Circle universe',
        maxPumps: 160,
      );
      await takeAcceptanceScreenshot(binding, tester, '05-circle');

      await openNavTab(tester, 'Messages');
      await waitForFinder(
        tester,
        find.text('Jordan'),
        description: 'seeded conversation',
        maxPumps: 160,
      );
      await takeAcceptanceScreenshot(binding, tester, '06-messages');

      await tester.tap(find.text('Jordan'));
      final composer = find.byKey(
        const Key('conversation-message-composer'),
      );
      await waitForFinder(
        tester,
        composer,
        description: 'conversation composer',
        maxPumps: 160,
      );

      const acceptanceMessage = 'Simulator acceptance message';
      await tester.enterText(composer, acceptanceMessage);
      await tester.tap(find.byTooltip('Send message'));
      await waitForFinder(
        tester,
        find.text(acceptanceMessage),
        description: 'sent simulator message',
        maxPumps: 160,
      );
      await takeAcceptanceScreenshot(binding, tester, '07-chat');

      await tester.pageBack();
      await waitForFinder(
        tester,
        navLabel('Profile'),
        description: 'main navigation after chat',
      );
      await openNavTab(tester, 'Profile');
      await waitForFinder(
        tester,
        find.text('View my profile'),
        description: 'self profile screen',
        maxPumps: 160,
      );
      final selfProfileName = find.text('Cam, 29');
      await tester.scrollUntilVisible(
        selfProfileName,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await takeAcceptanceScreenshot(binding, tester, '08-profile');

      await tester.tap(find.byTooltip('Safety center'));
      await waitForFinder(
        tester,
        find.text('Safety center'),
        description: 'Safety center',
      );
      await takeAcceptanceScreenshot(binding, tester, '09-safety');

      expect(tester.takeException(), isNull);
    },
  );
}
