import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/connections/connections_screen.dart';
import 'package:polycircle/services/profile_media_service.dart';

const alexConnection = <String, dynamic>{
  'uid': 'member-1',
  'displayName': 'Alex',
  'relationshipStatus': 'Dating',
};

Future<void> pumpConnections(
  WidgetTester tester, {
  required ConnectionsLoader loadConnections,
  required EndConnectionAction endConnection,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConnectionsScreen.test(
          loadConnections: loadConnections,
          endConnection: endConnection,
          loadVisiblePhotos: (_) async => const <VisibleProfilePhoto>[],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openEndConnectionDialog(WidgetTester tester) async {
  final menu = find.byType(PopupMenuButton<String>);
  expect(menu, findsOneWidget);

  await tester.ensureVisible(menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();

  await tester.tap(find.text('End connection'));
  await tester.pumpAndSettle();

  expect(find.text('End connection?'), findsOneWidget);
}

void main() {
  testWidgets(
    'End connection requires explicit confirmation',
    (tester) async {
      var endCalls = 0;

      await pumpConnections(
        tester,
        loadConnections: () async => [alexConnection],
        endConnection: (_) async {
          endCalls += 1;
        },
      );

      await openEndConnectionDialog(tester);

      expect(
        find.text(
          'Ending your connection with Alex will close the conversation and '
          'revoke any Private Vault access in both directions. This cannot be '
          'undone automatically.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(endCalls, 0);
      expect(find.text('Alex'), findsWidgets);
    },
  );

  testWidgets(
    'Confirmed end connection uses exact UID and reloads',
    (tester) async {
      var loadCalls = 0;
      var endCalls = 0;
      var ended = false;
      String? endedUid;

      await pumpConnections(
        tester,
        loadConnections: () async {
          loadCalls += 1;
          return ended ? const <Map<String, dynamic>>[] : [alexConnection];
        },
        endConnection: (uid) async {
          endCalls += 1;
          endedUid = uid;
          ended = true;
        },
      );

      await openEndConnectionDialog(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, 'End connection'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(endCalls, 1);
      expect(endedUid, 'member-1');
      expect(loadCalls, 2);
      expect(
        find.text('Your connections will live here'),
        findsOneWidget,
      );
      expect(
        find.text('Connection with Alex ended.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Failed end connection remains recoverable',
    (tester) async {
      var attempts = 0;
      var ended = false;

      await pumpConnections(
        tester,
        loadConnections: () async {
          return ended ? const <Map<String, dynamic>>[] : [alexConnection];
        },
        endConnection: (_) async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('temporary failure');
          }
          ended = true;
        },
      );

      await openEndConnectionDialog(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, 'End connection'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(attempts, 1);
      expect(find.text('Alex'), findsWidgets);
      expect(
        find.text('Could not end this connection right now.'),
        findsOneWidget,
      );
      expect(
        find.text('Connection with Alex ended.'),
        findsNothing,
      );

      var menu = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      expect(menu.enabled, isTrue);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await openEndConnectionDialog(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, 'End connection'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(attempts, 2);
      expect(
        find.text('Your connections will live here'),
        findsOneWidget,
      );
      expect(
        find.text('Connection with Alex ended.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Pending end connection blocks duplicate submission',
    (tester) async {
      final pendingEnd = Completer<void>();
      var endCalls = 0;
      var loadCalls = 0;
      var ended = false;

      await pumpConnections(
        tester,
        loadConnections: () async {
          loadCalls += 1;
          return ended ? const <Map<String, dynamic>>[] : [alexConnection];
        },
        endConnection: (_) {
          endCalls += 1;
          return pendingEnd.future;
        },
      );

      await openEndConnectionDialog(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, 'End connection'),
      );
      await tester.pumpAndSettle();

      expect(endCalls, 1);

      final menu = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      expect(menu.enabled, isFalse);

      await tester.tap(
        find.byType(PopupMenuButton<String>),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(endCalls, 1);
      expect(find.text('End connection?'), findsNothing);

      ended = true;
      pendingEnd.complete();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(endCalls, 1);
      expect(loadCalls, 2);
      expect(
        find.text('Your connections will live here'),
        findsOneWidget,
      );
    },
  );
}
