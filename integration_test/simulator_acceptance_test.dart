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
    'seeded iPhone simulator completes the pre-billing core journey',
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

        final terms = find.text('I am 18+ and accept the Terms of Use');
        await tester.ensureVisible(terms);
        await tester.tap(terms);

        final guidelines = find.text('I accept the Community Guidelines');
        await tester.ensureVisible(guidelines);
        await tester.tap(guidelines);

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

      await openNavTab(tester, 'Connections');
      await waitForFinder(
        tester,
        find.text('Jordan'),
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
        find.text('Cam, 29'),
        description: 'self profile preview',
        maxPumps: 160,
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
