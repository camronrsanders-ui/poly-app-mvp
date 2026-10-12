import 'package:flutter/foundation.dart' show defaultTargetPlatform;
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

/// A successful send is not usable if the new bubble sits underneath
/// the composer. Wait for the app's own follow-to-latest behavior; do not
/// scroll on behalf of the app and hide a real chat UX defect.
Future<void> waitForMessageAboveComposer(
  WidgetTester tester, {
  required String messageText,
  required Finder composer,
  int maxPumps = 48,
}) async {
  // Checking only the Text rect misses a cropped message bubble: its Sent
  // receipt can be hidden under the composer while all text remains visible.
  // The _MessageBubble Semantics node encloses the text, timestamp and receipt.
  final completeBubble = find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        (widget.properties.label ?? '').contains('You, $messageText'),
    description: 'complete sent-message bubble and delivery receipt',
  );
  final busySend = find.descendant(
    of: find.byTooltip('Send message'),
    matching: find.byType(CircularProgressIndicator),
  );
  double? lastBubbleBottom;
  double? lastComposerTop;
  for (var attempt = 0; attempt < maxPumps; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 250));
    if (completeBubble.evaluate().length != 1 ||
        composer.evaluate().length != 1 ||
        busySend.evaluate().isNotEmpty) {
      continue;
    }
    lastBubbleBottom = tester.getRect(completeBubble).bottom;
    lastComposerTop = tester.getRect(composer).top;
    if (lastBubbleBottom < lastComposerTop - 8) return;
  }
  throw TestFailure(
    'Entire sent-message bubble (including receipt) must appear above the '
    'composer with Send idle: bubble bottom=$lastBubbleBottom, '
    'composer top=$lastComposerTop, busy=${busySend.evaluate().isNotEmpty}.',
  );
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

/// A route title can enter the widget tree on the first frame of the
/// Cupertino/Material push animation. Its screenshot is not representative
/// until the foreground route is current and fully visible.
Future<void> waitForForegroundRouteSettled(
  WidgetTester tester,
  Finder screenTitle, {
  required String description,
  int maxPumps = 100,
}) async {
  AnimationStatus? lastAnimationStatus;
  for (var attempt = 0; attempt < maxPumps; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    if (screenTitle.evaluate().isEmpty) continue;
    final route = ModalRoute.of(tester.element(screenTitle.first));
    lastAnimationStatus = route?.animation?.status;
    if (route?.isCurrent == true &&
        (lastAnimationStatus == null ||
            lastAnimationStatus == AnimationStatus.completed)) {
      return;
    }
  }
  throw TestFailure(
    '$description was not the settled foreground route: '
    'animation=$lastAnimationStatus.',
  );
}

Future<void> takeAcceptanceScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await tester.pump(const Duration(milliseconds: 300));
  final widgetException = tester.takeException();
  if (widgetException != null) {
    throw TestFailure(
      'Unexpected widget/layout error at acceptance checkpoint $name: '
      '$widgetException',
    );
  }
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

      if (_captureAcceptanceScreenshots &&
          defaultTargetPlatform == TargetPlatform.android) {
        // Android integration_test screenshots require a Flutter image-backed
        // surface. This is debug-test-only and never changes production UI.
        await binding.convertFlutterSurfaceToImage();
      }

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
        find.byKey(const Key('discovery-connect')),
        description: 'Discover profile action by unique key',
        maxPumps: 240,
      );
      expect(find.text('Pass'), findsOneWidget);
      // The Connect action may be laid out while a new candidate page is
      // loading. An image of the spinner is not acceptable Discover evidence.
      await waitForFinder(
        tester,
        find.text('1 / 2'),
        description: 'loaded two-person Discover counter before screenshot',
        maxPumps: 240,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Finding nearby worlds…'), findsNothing);
      expect(find.text('1 / 2'), findsOneWidget);
      await takeAcceptanceScreenshot(binding, tester, '03-discover');

      // Live iOS/Android regression for the two-person Discover fixture:
      // moving to Riley then passing must update the count immediately.
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

      await openNavTab(tester, 'Connect');
      await waitForFinder(
        tester,
        find.textContaining('Jordan'),
        description: 'seeded connection',
        maxPumps: 160,
      );
      // A Discover Pass confirmation must not obstruct another tab.
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Passed'), findsNothing);
      await takeAcceptanceScreenshot(binding, tester, '04-connections');

      // UI-14: inspect a real seeded member's public profile through its
      // existing Connection options. Only open the safety menu; never report,
      // block, or send interest as part of screenshot acceptance.
      final connectionOptions = find.byTooltip('Connection options');
      // A Finder.first throws before scrollUntilVisible can bring a lazy
      // child into existence. Keep the unfiltered Finder through the scroll.
      await tester.scrollUntilVisible(
        connectionOptions,
        180,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      expect(connectionOptions, findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(connectionOptions),
        alignment: 0.5,
        duration: const Duration(milliseconds: 180),
      );
      await tester.pumpAndSettle();
      // Verify the popup really opened; a clipped tap must not count.
      await tester.tap(connectionOptions);
      await tester.pumpAndSettle();
      await waitForFinder(
        tester,
        find.text('View profile'),
        description: 'open Connections options menu',
      );
      expect(find.text('Open chat'), findsOneWidget);
      expect(find.text('End connection'), findsOneWidget);
      await tester.tap(find.text('View profile'));
      await waitForFinder(
        tester,
        find.text('Step into their world'),
        description: 'connected member public profile',
        maxPumps: 160,
      );
      await waitForForegroundRouteSettled(
        tester,
        find.text('Step into their world'),
        description: 'Member profile detail',
      );
      // Both media and consent-filtered Circle details are asynchronous.
      // A spinner is not acceptable proof of the completed member page.
      var memberProfileLoaded = false;
      for (var pump = 0; pump < 160; pump += 1) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          memberProfileLoaded = true;
          break;
        }
      }
      expect(
        memberProfileLoaded,
        isTrue,
        reason: 'Member profile media and Circle must finish loading.',
      );
      final memberSafetyOptions = find.byType(PopupMenuButton<String>);
      expect(memberSafetyOptions, findsOneWidget);
      await tester.tap(memberSafetyOptions);
      await tester.pumpAndSettle();
      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Block'), findsOneWidget);
      await tester.pageBack();
      await waitForFinder(
        tester,
        find.text('Step into their world'),
        description: 'member profile after dismissing safety menu',
      );
      await takeAcceptanceScreenshot(
        binding,
        tester,
        '04a-member-profile',
      );
      await tester.pageBack();
      await waitForFinder(
        tester,
        find.textContaining('Jordan'),
        description: 'Connections restored after member profile',
        maxPumps: 160,
      );

      await openNavTab(tester, 'Circle');
      await waitForFinder(
        tester,
        find.text('Your relationship universe'),
        description: 'My Circle universe',
        maxPumps: 160,
      );
      // The Universe heading is available even when FutureBuilder is still
      // showing its spinner. Do not accept a loading view as Circle evidence.
      await waitForFinder(
        tester,
        find.byKey(const ValueKey('mine')),
        description: 'rendered My Circle orbit rather than loading state',
        maxPumps: 160,
      );
      await takeAcceptanceScreenshot(binding, tester, '05-circle');

      // Verify that an actual Circle options button opens Relationship Manager,
      // that its Firestore-backed view resolves, and that Back returns to the
      // existing orbit without creating or changing any relationship card.
      await tester.tap(find.byTooltip('Circle options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage relationships'));
      await waitForFinder(
        tester,
        find.text('Manage My Circle'),
        description: 'Relationship Manager screen title',
      );
      await waitForAny(
        tester,
        <Finder>[
          find.text('Build your circle'),
          find.textContaining('Your relationship cards can be public'),
        ],
        maxPumps: 160,
      );
      await takeAcceptanceScreenshot(
        binding,
        tester,
        '05a-relationship-manager',
      );
      await tester.pageBack();
      await waitForFinder(
        tester,
        find.byKey(const ValueKey('mine')),
        description: 'My Circle orbit after exiting Relationship Manager',
        maxPumps: 160,
      );

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
      // Send is disabled for blank drafts until the next rendered frame.
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await waitForFinder(
        tester,
        find.text(acceptanceMessage),
        description: 'sent simulator message',
        maxPumps: 160,
      );
      await waitForMessageAboveComposer(
        tester,
        messageText: acceptanceMessage,
        composer: composer,
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

      // UI-12: the owner must be able to open profile editing and safely
      // return without unintentionally mutating any personal information.
      final editProfile = find.text('Edit profile');
      // The self-profile scroll is down at Cam's details after screenshot 08.
      // Flutter lazily builds the earlier edit button; ensureVisible on an
      // unbuilt widget fails instead of scrolling toward it.
      await tester.scrollUntilVisible(
        editProfile,
        -200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      // The first visible frame can leave the label underneath the fixed
      // app bar (Android previously tried to tap it at y=54 and missed).
      await Scrollable.ensureVisible(
        tester.element(editProfile),
        alignment: 0.5,
        duration: const Duration(milliseconds: 180),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(editProfile).center.dy, greaterThan(90));
      await tester.tap(editProfile);
      await tester.pumpAndSettle();
      await waitForFinder(
        tester,
        find.text('Manage profile photos'),
        description: 'loaded editable profile settings',
        maxPumps: 160,
      );
      await waitForForegroundRouteSettled(
        tester,
        find.text('Edit profile'),
        description: 'Edit profile settings',
      );
      final nameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Display name',
        description: 'owner display-name editor',
      );
      expect(nameField, findsOneWidget);
      await takeAcceptanceScreenshot(
        binding,
        tester,
        '08a-profile-settings',
      );
      // The settings page is a lazy ListView. Prove that the bottom Save and
      // account controls are actually reachable rather than asserting on an
      // offscreen/unbuilt widget.
      final saveProfile = find.text('Save profile');
      await tester.scrollUntilVisible(
        saveProfile,
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(saveProfile, findsOneWidget);
      final logout = find.text('Log out');
      await tester.scrollUntilVisible(
        logout,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(logout, findsOneWidget);
      final deleteAccount = find.text('Delete my account');
      await tester.scrollUntilVisible(
        deleteAccount,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(deleteAccount, findsOneWidget);
      await takeAcceptanceScreenshot(
        binding,
        tester,
        '08b-profile-settings-actions',
      );
      // Do not submit, sign out or initiate account deletion.
      await tester.pageBack();
      await waitForFinder(
        tester,
        find.text('View my profile'),
        description: 'self profile after abandoning profile edit',
        maxPumps: 160,
      );

      await tester.tap(find.byTooltip('Safety center'));
      await waitForFinder(
        tester,
        find.text('Safety center'),
        description: 'Safety center',
      );
      await waitForForegroundRouteSettled(
        tester,
        find.text('Safety center'),
        description: 'Safety Center',
      );
      await takeAcceptanceScreenshot(binding, tester, '09-safety');

      expect(tester.takeException(), isNull);
    },
  );
}
