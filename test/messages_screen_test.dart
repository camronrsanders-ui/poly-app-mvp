import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/messages/messages_screen.dart';

Future<void> pumpMessages(
  WidgetTester tester, {
  required ConversationListLoader loadConnections,
  required ConversationListLoader loadBlockedUsers,
  OpenConversationAction? openConversation,
}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MessagesScreen(
          loadConnections: loadConnections,
          loadBlockedUsers: loadBlockedUsers,
          openConversation: openConversation,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> conversation({
  required String uid,
  required String name,
  required String conversationId,
  required int lastMessageAtMs,
  String preview = 'Hello',
}) =>
    <String, dynamic>{
      'uid': uid,
      'displayName': name,
      'conversationId': conversationId,
      'lastMessageAtMs': lastMessageAtMs,
      'lastMessagePreview': preview,
    };

void main() {
  testWidgets(
    'conversation list filters blocked or malformed rows and sorts newest first',
    (tester) async {
      await pumpMessages(
        tester,
        loadConnections: () async => [
          conversation(
            uid: 'alex',
            name: 'Alex',
            conversationId: 'chat-alex',
            lastMessageAtMs: 100,
          ),
          conversation(
            uid: 'bailey',
            name: 'Bailey',
            conversationId: 'chat-bailey',
            lastMessageAtMs: 400,
          ),
          conversation(
            uid: 'devon',
            name: 'Devon',
            conversationId: 'chat-devon',
            lastMessageAtMs: 300,
          ),
          <String, dynamic>{
            'uid': 'casey',
            'displayName': 'Casey',
            'lastMessageAtMs': 500,
          },
        ],
        loadBlockedUsers: () async => [
          <String, dynamic>{'blockedUid': 'bailey'},
        ],
      );

      expect(find.text('Bailey'), findsNothing);
      expect(find.text('Casey'), findsNothing);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Devon'), findsOneWidget);

      final devonY = tester.getTopLeft(find.text('Devon')).dy;
      final alexY = tester.getTopLeft(find.text('Alex')).dy;
      expect(devonY, lessThan(alexY));
    },
  );

  testWidgets(
    'tapping a conversation opens the exact target and refreshes on return',
    (tester) async {
      var loadCalls = 0;
      String? openedConversationId;
      String? openedUid;
      String? openedName;

      await pumpMessages(
        tester,
        loadConnections: () async {
          loadCalls += 1;
          return [
            conversation(
              uid: 'alex',
              name: 'Alex',
              conversationId: 'chat-alex',
              lastMessageAtMs: 100,
            ),
          ];
        },
        loadBlockedUsers: () async => const <Map<String, dynamic>>[],
        openConversation: ({
          required conversationId,
          required otherUid,
          required otherDisplayName,
        }) async {
          openedConversationId = conversationId;
          openedUid = otherUid;
          openedName = otherDisplayName;
        },
      );

      await tester.tap(find.text('Alex'));
      await tester.pumpAndSettle();

      expect(openedConversationId, 'chat-alex');
      expect(openedUid, 'alex');
      expect(openedName, 'Alex');
      expect(loadCalls, 2);
    },
  );

  testWidgets(
    'failed load exposes a working retry action',
    (tester) async {
      var attempts = 0;

      await pumpMessages(
        tester,
        loadConnections: () async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('temporary load failure');
          }
          return [
            conversation(
              uid: 'alex',
              name: 'Alex',
              conversationId: 'chat-alex',
              lastMessageAtMs: 100,
            ),
          ];
        },
        loadBlockedUsers: () async => const <Map<String, dynamic>>[],
      );

      expect(find.text('Could not load conversations'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Could not load conversations'), findsNothing);
    },
  );

  testWidgets(
    'empty conversation state remains refreshable',
    (tester) async {
      var loads = 0;

      await pumpMessages(
        tester,
        loadConnections: () async {
          loads += 1;
          return const <Map<String, dynamic>>[];
        },
        loadBlockedUsers: () async => const <Map<String, dynamic>>[],
      );

      expect(find.text('No conversations yet'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 500));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(loads, greaterThanOrEqualTo(2));
    },
  );
}
