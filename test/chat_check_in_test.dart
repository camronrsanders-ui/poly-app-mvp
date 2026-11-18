import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/messages/chat_screen.dart';
import 'package:polycircle/services/check_in_service.dart';

Future<void> _noopReport({
  required String reportedUid,
  required String reason,
  required String details,
  required String contentType,
  String? contentId,
  String? conversationId,
}) async {}

void main() {
  testWidgets(
    'chat screen shows the check-in card with both current states',
    (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      var loads = 0;
      final actions = CheckInActions(
        load: () async {
          loads++;
          return CheckInSnapshot(
            otherUid: 'member-2',
            myState: CheckInSlot(
              state: 'celebrating',
              note: 'Got the job!',
              updatedAtMs: now - 30 * 60_000,
              expiresAtMs: now + 23 * 60 * 60_000,
            ),
            otherState: CheckInSlot(
              state: 'okay',
              note: '',
              updatedAtMs: now - 60 * 60_000,
              expiresAtMs: now + 22 * 60 * 60_000,
            ),
            sharedNote: null,
          );
        },
        setMyState: ({required state, note = ''}) async {},
        clearMyState: () async {},
        setSharedNote: (_) async {},
        clearSharedNote: () async {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen.test(
            conversationId: 'conversation-1',
            otherUid: 'member-2',
            otherDisplayName: 'Alex',
            currentUid: 'member-1',
            sendAction: ({required conversationId, required text}) async {},
            endConnectionAction: (_) async {},
            blockAction: (_) async {},
            reportAction: _noopReport,
            checkInActions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Collapsed by default (H-5): the one-line summary carries both
      // current state labels, and the full card is not rendered.
      expect(find.byKey(const Key('check-in-card')), findsOneWidget);
      expect(
        find.text('You: Celebrating something · Alex: Okay'),
        findsOneWidget,
      );
      expect(find.text('Got the job!'), findsNothing);
      expect(loads, greaterThan(0));

      // Expanding reveals the full card, unchanged inside.
      await tester.tap(find.byKey(const Key('check-in-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Celebrating something'), findsOneWidget);
      expect(find.text('Got the job!'), findsOneWidget);
      expect(find.text('Okay'), findsOneWidget);
    },
  );

  testWidgets(
    'chat screen does not overflow on a short keyboard-reduced viewport',
    (tester) async {
      // Mirrors the Android acceptance failure: the software keyboard
      // shrinks the body until the check-in card's natural height plus
      // the composer no longer fit. The card must yield space (scroll
      // internally) instead of overflowing the chat column and
      // squeezing the message list to zero height.
      tester.view.physicalSize = const Size(411, 340);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final actions = CheckInActions(
        load: () async => const CheckInSnapshot(
          otherUid: 'member-2',
          myState: null,
          otherState: null,
          sharedNote: null,
        ),
        setMyState: ({required state, note = ''}) async {},
        clearMyState: () async {},
        setSharedNote: (_) async {},
        clearSharedNote: () async {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen.test(
            conversationId: 'conversation-1',
            otherUid: 'member-2',
            otherDisplayName: 'Alex',
            currentUid: 'member-1',
            sendAction: ({required conversationId, required text}) async {},
            endConnectionAction: (_) async {},
            blockAction: (_) async {},
            reportAction: _noopReport,
            checkInActions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('check-in-card')), findsOneWidget);
      expect(
        find.byKey(const Key('conversation-message-composer')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'returning to the app refreshes the check-in card',
    (tester) async {
      var loads = 0;
      final actions = CheckInActions(
        load: () async {
          loads++;
          return const CheckInSnapshot(
            otherUid: 'member-2',
            myState: null,
            otherState: null,
            sharedNote: null,
          );
        },
        setMyState: ({required state, note = ''}) async {},
        clearMyState: () async {},
        setSharedNote: (_) async {},
        clearSharedNote: () async {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen.test(
            conversationId: 'conversation-1',
            otherUid: 'member-2',
            otherDisplayName: 'Alex',
            currentUid: 'member-1',
            sendAction: ({required conversationId, required text}) async {},
            endConnectionAction: (_) async {},
            blockAction: (_) async {},
            reportAction: _noopReport,
            checkInActions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, 1);

      // App resume is a freshness trigger (H-4): the card reloads
      // without the member leaving and re-entering the chat.
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();
      expect(loads, 2);
    },
  );

  testWidgets(
    'expanded card keeps the conversation floor with the keyboard open',
    (tester) async {
      // A tall phone with the software keyboard open: the body shrinks
      // to ~524px. The legacy flat reserve left the conversation
      // 240 minus the composer's height (~168px, about two bubbles);
      // the floor formula (H-5) guarantees the conversation its 240
      // first and lets the expanded card scroll internally instead.
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final now = DateTime.now().millisecondsSinceEpoch;
      final actions = CheckInActions(
        load: () async => CheckInSnapshot(
          otherUid: 'member-2',
          myState: CheckInSlot(
            state: 'celebrating',
            note: 'Got the job!',
            updatedAtMs: now - 30 * 60_000,
            expiresAtMs: now + 23 * 60 * 60_000,
          ),
          otherState: CheckInSlot(
            state: 'okay',
            note: '',
            updatedAtMs: now - 60 * 60_000,
            expiresAtMs: now + 22 * 60 * 60_000,
          ),
          sharedNote: SharedCheckInNote(
            text: 'Dinner at 7 on Friday.',
            updatedByUid: 'member-2',
            updatedAtMs: now - 60_000,
          ),
        ),
        setMyState: ({required state, note = ''}) async {},
        clearMyState: () async {},
        setSharedNote: (_) async {},
        clearSharedNote: () async {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen.test(
            conversationId: 'conversation-1',
            otherUid: 'member-2',
            otherDisplayName: 'Alex',
            currentUid: 'member-1',
            sendAction: ({required conversationId, required text}) async {},
            endConnectionAction: (_) async {},
            blockAction: (_) async {},
            reportAction: _noopReport,
            checkInActions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('check-in-toggle')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The card is capped (it scrolls internally) ...
      final cardViewport = tester.getRect(
        find.ancestor(
          of: find.byKey(const Key('check-in-card')),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(cardViewport.height, lessThanOrEqualTo(212));

      // ... and the conversation region (the empty state's Center
      // fills the Expanded list area) keeps its floor: room for at
      // least three ~56px message bubbles, where the legacy layout
      // left about two.
      final listRect = tester.getRect(
        find.ancestor(
          of: find.text('Start your conversation'),
          matching: find.byType(Center),
        ),
      );
      expect(listRect.height, greaterThanOrEqualTo(234));
    },
  );

  testWidgets(
    'expanded card renders at natural height on a tall viewport',
    (tester) async {
      tester.view.physicalSize = const Size(411, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now().millisecondsSinceEpoch;
      final actions = CheckInActions(
        load: () async => CheckInSnapshot(
          otherUid: 'member-2',
          myState: CheckInSlot(
            state: 'celebrating',
            note: 'Got the job!',
            updatedAtMs: now - 30 * 60_000,
            expiresAtMs: now + 23 * 60 * 60_000,
          ),
          otherState: CheckInSlot(
            state: 'okay',
            note: '',
            updatedAtMs: now - 60 * 60_000,
            expiresAtMs: now + 22 * 60 * 60_000,
          ),
          sharedNote: SharedCheckInNote(
            text: 'Dinner at 7 on Friday.',
            updatedByUid: 'member-2',
            updatedAtMs: now - 60_000,
          ),
        ),
        setMyState: ({required state, note = ''}) async {},
        clearMyState: () async {},
        setSharedNote: (_) async {},
        clearSharedNote: () async {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen.test(
            conversationId: 'conversation-1',
            otherUid: 'member-2',
            otherDisplayName: 'Alex',
            currentUid: 'member-1',
            sendAction: ({required conversationId, required text}) async {},
            endConnectionAction: (_) async {},
            blockAction: (_) async {},
            reportAction: _noopReport,
            checkInActions: actions,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('check-in-toggle')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The whole expanded card fits without internal scrolling: even
      // its last action (the shared note's Edit button) sits inside
      // the card's viewport.
      final cardViewport = tester.getRect(
        find.ancestor(
          of: find.byKey(const Key('check-in-card')),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final editNote = tester.getRect(
        find.byKey(const Key('check-in-edit-note')),
      );
      expect(editNote.bottom, lessThanOrEqualTo(cardViewport.bottom + 1));
      expect(cardViewport.height, greaterThan(300));
    },
  );
}
