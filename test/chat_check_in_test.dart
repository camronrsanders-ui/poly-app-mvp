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
}
