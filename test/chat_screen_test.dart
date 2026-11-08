import 'dart:async';

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
  test('own newly sent messages override the history scroll position', () {
    expect(
      chatShouldFollowOwnSentMessage(
        awaitingOwnSend: true,
        currentUid: 'member-1',
        previousLastId: 'old-message',
        latestLastId: 'our-new-message',
        latestSenderUid: 'member-1',
      ),
      isTrue,
    );
    expect(
      chatShouldFollowOwnSentMessage(
        awaitingOwnSend: false,
        currentUid: 'member-1',
        previousLastId: 'old-message',
        latestLastId: 'our-new-message',
        latestSenderUid: 'member-1',
      ),
      isFalse,
    );
    expect(
      chatShouldFollowOwnSentMessage(
        awaitingOwnSend: true,
        currentUid: 'member-1',
        previousLastId: 'old-message',
        latestLastId: 'someone-elses-message',
        latestSenderUid: 'member-2',
      ),
      isFalse,
    );
    expect(
      chatShouldFollowOwnSentMessage(
        awaitingOwnSend: true,
        currentUid: 'member-1',
        previousLastId: 'same',
        latestLastId: 'same',
        latestSenderUid: 'member-1',
      ),
      isFalse,
    );
    expect(
      chatShouldFollowOwnSentMessage(
        awaitingOwnSend: true,
        currentUid: null,
        previousLastId: 'old',
        latestLastId: 'new',
        latestSenderUid: 'member-1',
      ),
      isFalse,
    );
  });

  test('latest message follows only when user is already near the chat tail',
      () {
    expect(
      chatShouldFollowLatest(
        didInitialScroll: true,
        wasNearBottom: true,
        previousLastId: 'older',
        latestLastId: 'newest',
      ),
      isTrue,
    );
    expect(
      chatShouldFollowLatest(
        didInitialScroll: true,
        wasNearBottom: false,
        previousLastId: 'older',
        latestLastId: 'newest',
      ),
      isFalse,
    );
    expect(
      chatShouldFollowLatest(
        didInitialScroll: true,
        wasNearBottom: true,
        previousLastId: 'same',
        latestLastId: 'same',
      ),
      isFalse,
    );
    expect(
      chatShouldFollowLatest(
        didInitialScroll: false,
        wasNearBottom: true,
        previousLastId: null,
        latestLastId: 'first',
      ),
      isFalse,
    );
    expect(
      chatShouldFollowLatest(
        didInitialScroll: true,
        wasNearBottom: true,
        previousLastId: 'last',
        latestLastId: null,
      ),
      isFalse,
    );
  });
  test('own-sent follow keeps re-pinning while the extent is still growing',
      () {
    // Simulates the Android IME settling after the send snapshot: the
    // maxScrollExtent grows by ~34px in late steps (the acceptance
    // journey's stable 26px overlap plus required clearance), then stops.
    final tracker = OwnSentMessageFollowTracker(guardFrames: 3);
    expect(tracker.observeFrame(1000), isTrue);
    expect(tracker.observeFrame(1012), isTrue);
    expect(tracker.observeFrame(1034), isTrue);
    expect(tracker.observeFrame(1034), isTrue);
    // Second consecutive frame at the same extent: settled, but the
    // follow now guards against a late extent change instead of dying.
    expect(tracker.observeFrame(1034), isTrue);
    expect(tracker.isGuarding, isTrue);
    expect(tracker.guardedExtent, 1034);
    // Guard frames elapse with no further change: the follow ends.
    expect(tracker.observeFrame(1034), isTrue);
    expect(tracker.observeFrame(1034), isTrue);
    expect(tracker.observeFrame(1034), isFalse);
    expect(tracker.isActive, isFalse);
  });

  test('own-sent follow settles quickly when the viewport never moves', () {
    final tracker = OwnSentMessageFollowTracker(guardFrames: 2);
    expect(tracker.observeFrame(500), isTrue);
    expect(tracker.observeFrame(500), isTrue);
    // Stable for the second consecutive frame: settled into guard.
    expect(tracker.observeFrame(500), isTrue);
    expect(tracker.isGuarding, isTrue);
    expect(tracker.observeFrame(500), isTrue);
    expect(tracker.observeFrame(500), isFalse);
    expect(tracker.isActive, isFalse);
  });

  test('own-sent follow re-pins when the extent grows after settling', () {
    // The integrated QA failure mode: the extent plateaus long enough
    // to settle, then grows again (a late IME inset step or the send
    // acknowledgement's relayout). The follow must still be alive to
    // re-pin, or the sent bubble is stranded under the composer.
    final tracker = OwnSentMessageFollowTracker(guardFrames: 8);
    expect(tracker.observeFrame(1000), isTrue);
    expect(tracker.observeFrame(1000), isTrue);
    expect(tracker.observeFrame(1000), isTrue);
    expect(tracker.isGuarding, isTrue);
    // A few guard frames pass at the settled extent.
    expect(tracker.observeFrame(1000), isTrue);
    expect(tracker.observeFrame(1000), isTrue);
    // The extent grows by 22 (the measured QA shortfall): the follow
    // resumes re-pinning instead of staying settled.
    expect(tracker.observeFrame(1022), isTrue);
    expect(tracker.isGuarding, isFalse);
    expect(tracker.isActive, isTrue);
    // It settles again at the new extent and guards once more.
    expect(tracker.observeFrame(1022), isTrue);
    expect(tracker.observeFrame(1022), isTrue);
    expect(tracker.isGuarding, isTrue);
    expect(tracker.guardedExtent, 1022);
  });

  test('own-sent follow is bounded across follow and guard phases', () {
    final tracker = OwnSentMessageFollowTracker(
      maxFrames: 4,
      guardFrames: 3,
    );
    expect(tracker.observeFrame(100), isTrue);
    expect(tracker.observeFrame(100), isTrue);
    // Settled into the guard phase.
    expect(tracker.observeFrame(100), isTrue);
    expect(tracker.observeFrame(100), isTrue);
    // A late growth resumes the follow, but the combined frame budget
    // still ends it.
    expect(tracker.observeFrame(130), isTrue);
    expect(tracker.observeFrame(130), isTrue);
    expect(tracker.observeFrame(130), isFalse);
    expect(tracker.isActive, isFalse);
  });

  test('own-sent follow stops at the frame cap if the extent never settles',
      () {
    final tracker = OwnSentMessageFollowTracker(maxFrames: 3);
    expect(tracker.observeFrame(100), isTrue);
    expect(tracker.observeFrame(200), isTrue);
    expect(tracker.observeFrame(300), isFalse);
    expect(tracker.isActive, isFalse);
  });

  test('own-sent follow stops immediately when the member drags', () {
    final tracker = OwnSentMessageFollowTracker();
    expect(tracker.observeFrame(100), isTrue);
    tracker.cancel();
    expect(tracker.isActive, isFalse);
    expect(tracker.observeFrame(200), isFalse);
  });

  testWidgets(
    'Send is disabled for blank or whitespace-only drafts and after send',
    (tester) async {
      var sends = 0;
      await pumpChat(
        tester,
        sendAction: ({required conversationId, required text}) async {
          sends += 1;
        },
      );

      final composer = find.byKey(const Key('conversation-message-composer'));
      final send = find.byTooltip('Send message');
      final sendButton = find.ancestor(
        of: send,
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);

      await tester.enterText(composer, '   ');
      await tester.pump();
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
      expect(sends, 0);

      await tester.enterText(composer, ' Hello ');
      await tester.pump();
      expect(tester.widget<IconButton>(sendButton).onPressed, isNotNull);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Send becomes disabled during an in-flight message submission',
    (tester) async {
      final pending = Completer<void>();
      var sends = 0;
      await pumpChat(
        tester,
        sendAction: ({required conversationId, required text}) async {
          sends += 1;
          await pending.future;
        },
      );

      final composer = find.byKey(const Key('conversation-message-composer'));
      final send = find.byTooltip('Send message');
      final sendButton = find.ancestor(
        of: send,
        matching: find.byType(IconButton),
      );
      await tester.enterText(composer, 'Hello');
      await tester.pump();
      expect(tester.widget<IconButton>(sendButton).onPressed, isNotNull);
      await tester.tap(send);
      await tester.pump();
      expect(sends, 1);
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);

      pending.complete();
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

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
      await tester.pump();
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
      await tester.pump();
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
