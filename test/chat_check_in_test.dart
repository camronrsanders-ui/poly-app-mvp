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

      expect(find.byKey(const Key('check-in-card')), findsOneWidget);
      expect(find.text('Celebrating something'), findsOneWidget);
      expect(find.text('Got the job!'), findsOneWidget);
      expect(find.text('Okay'), findsOneWidget);
      expect(loads, greaterThan(0));
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
}
