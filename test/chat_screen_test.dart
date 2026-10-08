import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/messages/chat_screen.dart';

Future<void> noopMemberAction(String otherUid) async {}

Future<void> noopReport({
  required String reportedUid,
  required String reason,
  required String details,
  required String contentType,
  String? contentId,
  String? conversationId,
}) async {}

Future<void> pumpChat(
  WidgetTester tester, {
  ChatSendAction? sendAction,
  ChatMemberAction? endConnectionAction,
  ChatMemberAction? blockAction,
  ChatReportAction? reportAction,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen.test(
                    conversationId: 'conversation-1',
                    otherUid: 'member-2',
                    otherDisplayName: 'Alex',
                    currentUid: 'member-1',
                    sendAction: sendAction ??
                        ({required conversationId, required text}) async {},
                    endConnectionAction:
                        endConnectionAction ?? noopMemberAction,
                    blockAction: blockAction ?? noopMemberAction,
                    reportAction: reportAction ?? noopReport,
                  ),
                ),
              ),
              child: const Text('Open chat'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open chat'));
  await tester.pumpAndSettle();
}

Future<void> openSafetyMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Conversation safety options'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Send message trims text and invokes the trusted send action',
    (tester) async {
      String? sentConversationId;
      String? sentText;

      await pumpChat(
        tester,
        sendAction: ({required conversationId, required text}) async {
          sentConversationId = conversationId;
          sentText = text;
        },
      );

      final composer = find.byKey(
        const Key('conversation-message-composer'),
      );
      await tester.enterText(composer, '  Hello Alex  ');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      expect(sentConversationId, 'conversation-1');
      expect(sentText, 'Hello Alex');
      final field = tester.widget<TextField>(composer);
      expect(field.controller?.text, isEmpty);
    },
  );

  testWidgets(
    'Failed send restores the draft so the member can retry',
    (tester) async {
      await pumpChat(
        tester,
        sendAction: ({required conversationId, required text}) async {
          throw StateError('temporary send failure');
        },
      );

      final composer = find.byKey(
        const Key('conversation-message-composer'),
      );
      await tester.enterText(composer, 'Please retry');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(composer);
      expect(field.controller?.text, 'Please retry');
      expect(
        find.text(
          'Message failed to send. Your text was kept so you can retry.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'End connection requires confirmation and invokes the trusted action',
    (tester) async {
      var calls = 0;
      String? endedUid;

      await pumpChat(
        tester,
        endConnectionAction: (otherUid) async {
          calls += 1;
          endedUid = otherUid;
        },
      );

      await openSafetyMenu(tester);
      await tester.tap(find.text('End connection'));
      await tester.pumpAndSettle();

      expect(find.text('End connection with Alex?'), findsOneWidget);
      expect(calls, 0);

      await tester.tap(
        find.widgetWithText(FilledButton, 'End connection'),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(endedUid, 'member-2');
      expect(find.text('Open chat'), findsOneWidget);
    },
  );

  testWidgets(
    'Block requires confirmation and invokes the trusted action once',
    (tester) async {
      var calls = 0;
      String? blockedUid;

      await pumpChat(
        tester,
        blockAction: (otherUid) async {
          calls += 1;
          blockedUid = otherUid;
        },
      );

      await openSafetyMenu(tester);
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      expect(find.text('Block Alex?'), findsOneWidget);
      expect(calls, 0);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Block'),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(blockedUid, 'member-2');
      expect(find.text('Open chat'), findsOneWidget);
    },
  );

  testWidgets(
    'Report person submits an account report through the trusted action',
    (tester) async {
      String? capturedReportedUid;
      String? capturedReason;
      String? capturedContentType;
      String? capturedConversationId;

      await pumpChat(
        tester,
        reportAction: ({
          required String reportedUid,
          required String reason,
          required String details,
          required String contentType,
          String? contentId,
          String? conversationId,
        }) async {
          capturedReportedUid = reportedUid;
          capturedReason = reason;
          capturedContentType = contentType;
          capturedConversationId = conversationId;
        },
      );

      await openSafetyMenu(tester);
      await tester.tap(find.text('Report person'));
      await tester.pumpAndSettle();

      expect(find.text('Report Alex'), findsOneWidget);
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      expect(capturedReportedUid, 'member-2');
      expect(capturedReason, 'harassment');
      expect(capturedContentType, 'account');
      expect(capturedConversationId, isNull);
      expect(
        find.text(
          'Report submitted. Thank you for helping protect the community.',
        ),
        findsOneWidget,
      );
    },
  );
}
