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

Future<void> pumpBounded(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i += 1) {
    await tester.pump(const Duration(milliseconds: 250));
  }
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
    // A FlutterError's one-line summary hides which widget failed (PR
    // #70's 09b overflow named no culprit in any CI log). Include the
    // full diagnostics so a failure identifies the exact widget.
    final detail = widgetException is FlutterError
        ? widgetException.toStringDeep()
        : '$widgetException';
    throw TestFailure(
      'Unexpected widget/layout error at acceptance checkpoint $name: '
      '$detail',
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
        maxPumps: 320,
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
      // Connection tiles may animate indefinitely while loading photos;
      // jump to the centered option, then pump a bounded number of frames.
      await Scrollable.ensureVisible(
        tester.element(connectionOptions),
        alignment: 0.5,
        duration: Duration.zero,
      );
      await pumpBounded(tester);
      // Verify the popup really opened; a clipped tap must not count.
      await tester.tap(connectionOptions);
      await pumpBounded(tester);
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
      await pumpBounded(tester);
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

      // UI-18 / UI-19: Shared Moments and Shared Plans are feature-gated
      // OFF in the pre-billing build. Their only entry points are the
      // conversation app-bar actions, which must not be rendered at all
      // while the flags are off — no exposed entry or creation path, and
      // no dormant control that is accidentally interactive. (The
      // long-press "Save to Shared Moments" creation path is suppressed
      // by the same flag; that branch is pinned at source level by the
      // saved_message_moment_ui contract tests.)
      expect(
        find.byKey(const Key('conversation-shared-moments')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('conversation-shared-plans')),
        findsNothing,
      );
      expect(find.byTooltip('Shared moments'), findsNothing);
      expect(find.byTooltip('Plans'), findsNothing);

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
      // An awaited animated ensureVisible can deadlock a live widget test:
      // no frames advance the animation until this Future finishes. Snap to
      // the centered position, then pump bounded frames before the real tap.
      await Scrollable.ensureVisible(
        tester.element(editProfile),
        alignment: 0.5,
        duration: Duration.zero,
      );
      await pumpBounded(tester);
      expect(tester.getRect(editProfile).center.dy, greaterThan(90));
      await tester.tap(editProfile);
      await pumpBounded(tester);
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
      // UI-15: entering Photo management must not start a picker or upload.
      // The backend-backed gallery must resolve to a real empty/status view.
      await tester.tap(find.text('Manage profile photos'));
      await waitForFinder(
        tester,
        find.text('Protected profile photos'),
        description: 'private photo management route',
        maxPumps: 160,
      );
      await waitForForegroundRouteSettled(
        tester,
        find.text('Profile photos'),
        description: 'Profile Photos',
      );
      await waitForFinder(
        tester,
        find.text('Choose a photo'),
        description: 'available photo chooser button',
      );
      await waitForAny(
        tester,
        <Finder>[
          find.text('No profile photos yet'),
          find.text('Visible on your profile'),
          find.text('Processing securely'),
          find.text('Awaiting safety review'),
          find.text('Waiting for upload'),
          find.text('Not approved'),
          find.text('Removed'),
        ],
        maxPumps: 160,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
          find.text('Could not load profile photos right now.'), findsNothing);
      await takeAcceptanceScreenshot(
        binding,
        tester,
        '08aa-profile-photos',
      );
      await tester.pageBack();
      await waitForFinder(
        tester,
        find.text('Manage profile photos'),
        description: 'profile settings restored after photo management',
        maxPumps: 160,
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

      // UI-16: Safety Center entries, a real report submit, and the full
      // block/unblock cycle against the live backend. This segment must run
      // LAST: confirming a block permanently closes the seeded Cam+Jordan
      // match and conversation, and unblocking does not restore them, so
      // nothing after this segment may depend on that connection. Within
      // the segment the order is likewise fixed: the report and the block
      // dialog's Cancel happen before the confirmed block, because after
      // the block the chat route no longer exists.
      //
      // S1: the Safety Center is already the settled foreground route. Its
      // explainer sections are the acceptance row's "help entries"; there
      // is no separate Help button on this screen.
      expect(
        find.text('Your boundaries are part of the product'),
        findsOneWidget,
      );
      // S1b: the local moderator entry renders only for a session holding
      // a moderator claim; the seeded owner does not (this pre-covers the
      // non-staff cell of UI-17).
      await pumpBounded(tester);
      expect(find.text('Local moderator QA'), findsNothing);
      expect(find.text('Review pending profile photos'), findsNothing);
      final safetyScroll = find.byType(Scrollable).first;
      for (final heading in <String>[
        'Block at any time',
        'End a connection',
        'Report concerning behavior',
        'Severe content is blocked before posting',
        'Private media stays gated',
        'Profile photos are protected',
        'Keep location coarse',
        'Relationship descriptions are not verification',
        'Adults only',
      ]) {
        await tester.scrollUntilVisible(
          find.text(heading),
          300,
          scrollable: safetyScroll,
        );
        expect(find.text(heading), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.textContaining('not emergency services'),
        300,
        scrollable: safetyScroll,
      );
      expect(find.textContaining('not emergency services'), findsOneWidget);

      // Leaving a pushed route inside this segment cannot use
      // tester.pageBack(): on iOS the covered route's Back button stays
      // in the tree next to the foreground one, and pageBack() demands
      // exactly one — PR #70's first CI run threw "One back button
      // expected on screen — Found 2 widgets" at the S3 pageBack. Settle
      // the foreground route first, then tap ITS Back button (the last
      // 'Back' tooltip in traversal order is the topmost route's).
      Future<void> leaveViaForegroundBack({
        required Finder foregroundTitle,
        required String description,
      }) async {
        await waitForForegroundRouteSettled(
          tester,
          foregroundTitle,
          description: description,
        );
        await tester.tap(find.byTooltip('Back').last);
        await pumpBounded(tester);
      }

      // S2: the blocked-members entry resolves to the empty state on a
      // fresh seed (the seed creates no blocks, and its reset clears the
      // candidate blocks plus — since the UI-16 seed fix — Jordan's).
      final manageBlocked = find.text('Manage blocked members');
      await tester.scrollUntilVisible(
        manageBlocked,
        -300,
        scrollable: safetyScroll,
      );
      await tester.tap(manageBlocked);
      await waitForFinder(
        tester,
        find.text('Blocked members'),
        description: 'blocked members screen title',
        maxPumps: 160,
      );
      await waitForFinder(
        tester,
        find.text('No blocked members'),
        description: 'empty blocked members state',
        maxPumps: 160,
      );
      // A spinner is not acceptable evidence of the resolved empty state.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await takeAcceptanceScreenshot(
        binding,
        tester,
        '09a-blocked-members-empty',
      );
      await leaveViaForegroundBack(
        foregroundTitle: find.text('Blocked members'),
        description: 'Blocked members',
      );
      await waitForFinder(
        tester,
        find.text('Safety center'),
        description: 'Safety center after empty blocked list',
      );

      // S3: reach Jordan's chat safety controls. The popup-menu mitigation
      // from checkpoint 04a applies here too: pump bounded frames after
      // the tap, then wait for a menu item before tapping anything.
      Future<void> openConversationSafetyMenu() async {
        await tester.tap(find.byTooltip('Conversation safety options'));
        await pumpBounded(tester);
        await waitForFinder(
          tester,
          find.text('Report person'),
          description: 'open conversation safety menu',
        );
      }

      await leaveViaForegroundBack(
        foregroundTitle: find.text('Safety center'),
        description: 'Safety Center',
      );
      await waitForFinder(
        tester,
        find.text('View my profile'),
        description: 'self profile after Safety center',
        maxPumps: 160,
      );
      await openNavTab(tester, 'Messages');
      await waitForFinder(
        tester,
        find.text('Jordan'),
        description: 'seeded conversation before safety flows',
        maxPumps: 160,
      );
      await tester.tap(find.text('Jordan'));
      final safetyComposer = find.byKey(
        const Key('conversation-message-composer'),
      );
      await waitForFinder(
        tester,
        safetyComposer,
        description: 'conversation composer for safety flows',
        maxPumps: 160,
      );
      await openConversationSafetyMenu();
      expect(find.text('End connection'), findsOneWidget);
      expect(find.text('Block'), findsOneWidget);

      // S4: submit a real report against Jordan. The default reason is
      // sufficient; the backing callable writes one reports document and
      // changes no other visible state.
      await tester.tap(find.text('Report person'));
      await waitForFinder(
        tester,
        find.text('Report Jordan'),
        description: 'report dialog',
      );
      expect(find.text('Reason'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit report'));
      await waitForFinder(
        tester,
        find.text(
          'Report submitted. Thank you for helping protect the community.',
        ),
        description: 'report submitted confirmation',
        maxPumps: 160,
      );
      await pumpBounded(tester);

      // S5: open the block confirmation and back out without confirming,
      // mirroring the manual checklist's destructive-action discipline.
      await openConversationSafetyMenu();
      await tester.tap(find.text('Block'));
      await waitForFinder(
        tester,
        find.text('Block Jordan?'),
        description: 'block confirmation dialog',
      );
      expect(
        find.text(
          'They will no longer be able to interact with you through '
          'Polycircle. You can manage blocks later.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await pumpBounded(tester);
      expect(find.text('Block Jordan?'), findsNothing);
      expect(safetyComposer, findsOneWidget);

      // S6: confirm the block. blockUser closes the match and conversation
      // server-side and revokes private access, then the chat route pops
      // back to the main shell. Do not assert on Jordan's Messages tile
      // here; the blocked list in S7 is the authoritative observable.
      await openConversationSafetyMenu();
      await tester.tap(find.text('Block'));
      await waitForFinder(
        tester,
        find.text('Block Jordan?'),
        description: 'block confirmation dialog reopened',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await waitForFinder(
        tester,
        navLabel('Profile'),
        description: 'main navigation after blocking Jordan',
      );

      // S7: the blocked-members list now shows Jordan with an Unblock
      // action.
      await openNavTab(tester, 'Profile');
      await waitForFinder(
        tester,
        find.text('View my profile'),
        description: 'self profile before populated blocked list',
        maxPumps: 160,
      );
      await tester.tap(find.byTooltip('Safety center'));
      await waitForFinder(
        tester,
        find.text('Safety center'),
        description: 'Safety center for populated blocked list',
      );
      await tester.tap(find.text('Manage blocked members'));
      await waitForFinder(
        tester,
        find.text('Jordan'),
        description: 'blocked member Jordan',
        maxPumps: 160,
      );
      expect(
        find.text('Previous connections and private access stay closed.'),
        findsOneWidget,
      );
      expect(find.text('Unblock'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await takeAcceptanceScreenshot(
        binding,
        tester,
        '09b-blocked-members-jordan',
      );

      // S8: open the unblock confirmation and back out; the list must be
      // unchanged.
      await tester.tap(find.text('Unblock'));
      await waitForFinder(
        tester,
        find.text('Unblock Jordan?'),
        description: 'unblock confirmation dialog',
      );
      expect(
        find.text(
          'Unblocking allows future eligible interaction, but it does not '
          'restore a previous match, conversation, or private-media access.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await pumpBounded(tester);
      expect(find.text('Unblock Jordan?'), findsNothing);
      expect(find.text('Jordan'), findsOneWidget);
      expect(find.text('Unblock'), findsOneWidget);

      // S9: confirm the unblock. The screen refreshes itself; afterwards a
      // second unblock is unreachable in the UI, which is the drivable
      // half of the duplicate-action check (the backend half is pinned by
      // the safety functions and their tests).
      await tester.tap(find.text('Unblock'));
      await waitForFinder(
        tester,
        find.text('Unblock Jordan?'),
        description: 'unblock confirmation dialog reopened',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Unblock'));
      await waitForFinder(
        tester,
        find.text('Jordan unblocked.'),
        description: 'unblocked confirmation',
        maxPumps: 160,
      );
      await waitForFinder(
        tester,
        find.text('No blocked members'),
        description: 'blocked list cleared after unblock',
        maxPumps: 160,
      );
      expect(find.text('Unblock'), findsNothing);
      expect(find.text('Jordan'), findsNothing);
      await leaveViaForegroundBack(
        foregroundTitle: find.text('Blocked members'),
        description: 'Blocked members after unblock',
      );
      await waitForFinder(
        tester,
        find.text('Safety center'),
        description: 'Safety center after unblock',
      );
      await leaveViaForegroundBack(
        foregroundTitle: find.text('Safety center'),
        description: 'Safety Center',
      );
      await waitForFinder(
        tester,
        find.text('View my profile'),
        description: 'self profile at the end of the UI-16 segment',
        maxPumps: 160,
      );

      // Stack composition join: UI-16's segment ends on the self
      // profile, while UI-17's segment was written to start on the
      // Safety Center. Re-enter it with the same navigation the
      // journey used for 09-safety, so the segment below runs in
      // exactly the state it was verified in standalone.
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

      // UI-17 (non-staff cell): the local moderator entry must stay
      // hidden for a member session. Cam holds no moderator claim, so
      // the Safety Center card never renders here.
      expect(find.text('Local moderator QA'), findsNothing);
      expect(find.text('Review pending profile photos'), findsNothing);
      expect(tester.takeException(), isNull);

      // UI-17 (staff segment): sign out and return as the seeded local
      // moderator. This segment runs last and ends signed in as staff,
      // so nothing may follow it.
      await waitForForegroundRouteSettled(
        tester,
        find.text('Safety center'),
        description: 'Safety Center before sign-out',
      );
      await tester.tap(find.byTooltip('Back').last);
      await pumpBounded(tester);
      await waitForFinder(
        tester,
        find.text('View my profile'),
        description: 'self profile before sign-out',
      );
      final logOutTile = find.widgetWithText(ListTile, 'Log out');
      await tester.scrollUntilVisible(
        logOutTile,
        -200,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      await tester.ensureVisible(logOutTile);
      await pumpBounded(tester);
      await tester.tap(logOutTile);
      await waitForFinder(
        tester,
        find.text('Welcome back'),
        description: 'login screen after sign-out',
        maxPumps: 240,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'moderator@local.polycircle.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'LocalOnly123!',
      );
      final staffSignIn = find.widgetWithText(FilledButton, 'Sign in');
      await tester.ensureVisible(staffSignIn);
      await tester.tap(staffSignIn);

      final staffRoute = await waitForAny(
        tester,
        <Finder>[
          find.text('Adult access & community rules'),
          find.byType(NavigationBar),
        ],
        maxPumps: 320,
      );

      if (staffRoute.evaluate().any(
            (element) =>
                element.widget is Text &&
                (element.widget as Text).data ==
                    'Adult access & community rules',
          )) {
        // The moderator fixture predates the approval fields, so the
        // same adult-access gate Cam passed applies here. Work it
        // exactly as the member branch did, without a screenshot.
        await tester.tap(find.text('Date of birth'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        final staffGateScroll = find.byType(Scrollable).first;

        final staffTermsTile = find.widgetWithText(
          CheckboxListTile,
          'I am 18+ and accept the Terms of Use',
        );
        await tester.scrollUntilVisible(
          staffTermsTile,
          120,
          scrollable: staffGateScroll,
        );
        await tester.ensureVisible(staffTermsTile);
        await tester.pumpAndSettle();
        final staffTermsCheckbox = find.descendant(
          of: staffTermsTile,
          matching: find.byType(Checkbox),
        );
        await tester.tap(staffTermsCheckbox);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(staffTermsCheckbox).value, isTrue);

        final staffGuidelinesTile = find.widgetWithText(
          CheckboxListTile,
          'I accept the Community Guidelines',
        );
        await tester.scrollUntilVisible(
          staffGuidelinesTile,
          120,
          scrollable: staffGateScroll,
        );
        await tester.ensureVisible(staffGuidelinesTile);
        await tester.pumpAndSettle();
        final staffGuidelinesCheckbox = find.descendant(
          of: staffGuidelinesTile,
          matching: find.byType(Checkbox),
        );
        await tester.tap(staffGuidelinesCheckbox);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(staffGuidelinesCheckbox).value, isTrue);

        final staffVerifyLabel = find.text('Verify & continue');
        await tester.scrollUntilVisible(
          staffVerifyLabel,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(staffVerifyLabel);
      }

      await waitForFinder(
        tester,
        find.byType(NavigationBar),
        description: 'main shell as moderator',
        maxPumps: 240,
      );
      await openNavTab(tester, 'Profile');
      await waitForFinder(
        tester,
        find.text('View my profile'),
        description: 'moderator self profile',
        maxPumps: 160,
      );
      await tester.tap(find.byTooltip('Safety center'));
      await waitForFinder(
        tester,
        find.text('Safety center'),
        description: 'Safety center as moderator',
      );
      await waitForForegroundRouteSettled(
        tester,
        find.text('Safety center'),
        description: 'Safety Center as moderator',
      );
      // The entry renders only once the moderator claim check resolves.
      await waitForFinder(
        tester,
        find.text('Local moderator QA'),
        description: 'local moderator entry for staff',
        maxPumps: 240,
      );
      final reviewEntry = find.widgetWithText(
        FilledButton,
        'Review pending profile photos',
      );
      await tester.ensureVisible(reviewEntry);
      await tester.tap(reviewEntry);
      await waitForFinder(
        tester,
        find.text('Local photo moderation'),
        description: 'photo moderation queue screen',
        maxPumps: 160,
      );
      await waitForForegroundRouteSettled(
        tester,
        find.text('Local photo moderation'),
        description: 'Local photo moderation',
      );

      // The queue lists the two valid pending fixtures in processedAt
      // order: Jordan first, then Alex. Riley's malformed-path fixture
      // is filtered out server-side and must never appear, and both
      // previews must render rather than fall back to unavailable.
      await waitForFinder(
        tester,
        find.text('Jordan'),
        description: 'first pending moderation card',
        maxPumps: 240,
      );
      expect(find.text('Preview unavailable.'), findsNothing);
      expect(tester.takeException(), isNull);
      await takeAcceptanceScreenshot(binding, tester, '10-moderation-queue');

      final alexCard = find.widgetWithText(Card, 'Alex');
      await tester.scrollUntilVisible(
        alexCard,
        220,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      expect(alexCard, findsOneWidget);
      expect(find.text('Riley'), findsNothing);

      // Approve Jordan's photo: it leaves the pending queue.
      final jordanCard = find.widgetWithText(Card, 'Jordan');
      await tester.scrollUntilVisible(
        jordanCard,
        -220,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      final approveJordan = find.descendant(
        of: jordanCard,
        matching: find.widgetWithText(FilledButton, 'Approve'),
      );
      await tester.ensureVisible(approveJordan);
      await pumpBounded(tester);
      await tester.tap(approveJordan);
      await waitForFinder(
        tester,
        find.text('Approve this photo?'),
        description: 'approve confirmation dialog',
      );
      final confirmApprove = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Approve'),
      );
      await tester.tap(confirmApprove);
      await waitForFinder(
        tester,
        find.text('Photo approved.'),
        description: 'approve success snackbar',
        maxPumps: 240,
      );
      expect(tester.takeException(), isNull);
      var approvedCardGone = false;
      for (var attempt = 0; attempt < 160; attempt += 1) {
        await tester.pump(const Duration(milliseconds: 250));
        if (find.text('Jordan').evaluate().isEmpty) {
          approvedCardGone = true;
          break;
        }
      }
      expect(
        approvedCardGone,
        isTrue,
        reason: 'Approved photo must leave the pending queue.',
      );

      // Reject Alex's photo: the queue drains to its empty state.
      final rejectAlex = find.descendant(
        of: alexCard,
        matching: find.widgetWithText(OutlinedButton, 'Reject'),
      );
      await tester.scrollUntilVisible(
        rejectAlex,
        220,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      await tester.ensureVisible(rejectAlex);
      await pumpBounded(tester);
      await tester.tap(rejectAlex);
      await waitForFinder(
        tester,
        find.text('Reject this photo?'),
        description: 'reject confirmation dialog',
      );
      final confirmReject = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Reject'),
      );
      await tester.tap(confirmReject);
      await waitForFinder(
        tester,
        find.text('Photo rejected.'),
        description: 'reject success snackbar',
        maxPumps: 240,
      );
      expect(tester.takeException(), isNull);
      await waitForFinder(
        tester,
        find.text('No photos awaiting review'),
        description: 'empty moderation queue',
        maxPumps: 240,
      );
      expect(find.text('Alex'), findsNothing);
      expect(tester.takeException(), isNull);
      await takeAcceptanceScreenshot(binding, tester, '10-moderation-empty');

      expect(tester.takeException(), isNull);
    },
  );
}
