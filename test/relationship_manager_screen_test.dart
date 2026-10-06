import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/circle/relationship_manager_screen.dart';

Map<String, dynamic> card({
  required String id,
  required String label,
  String connectionType = 'romantic_partner',
  String status = 'active',
  String visibility = 'matches_only',
}) =>
    <String, dynamic>{
      'id': id,
      'ownerUid': 'member-1',
      'label': label,
      'connectionType': connectionType,
      'displayNameOptional': '',
      'status': status,
      'note': '',
      'visibility': visibility,
      'sortOrder': 0,
      'isActive': true,
    };

Future<void> pumpManager(
  WidgetTester tester, {
  required RelationshipCardsWatcher watchCards,
  CreateRelationshipCardAction? createCard,
  UpdateRelationshipCardAction? updateCard,
  RelationshipCardIdAction? deactivateCard,
  RelationshipCardIdAction? deleteCard,
  ReorderRelationshipCardsAction? reorderCards,
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RelationshipManagerScreen(
          uidProvider: () => 'member-1',
          watchCards: watchCards,
          createCard: createCard,
          updateCard: updateCard,
          deactivateCard: deactivateCard,
          deleteCard: deleteCard,
          reorderCards: reorderCards,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapMenuAction(
  WidgetTester tester,
  String action, {
  int menuIndex = 0,
}) async {
  final menus = find.byType(PopupMenuButton<String>);
  await tester.tap(menus.at(menuIndex));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Empty state Add relationship creates an exact trimmed card',
    (tester) async {
      Map<String, dynamic>? created;

      await pumpManager(
        tester,
        watchCards: (uid) => Stream.value(const []),
        createCard: ({
          required ownerUid,
          required label,
          required connectionType,
          required status,
          required note,
          required visibility,
          required displayNameOptional,
          required sortOrder,
        }) async {
          created = <String, dynamic>{
            'ownerUid': ownerUid,
            'label': label.trim(),
            'connectionType': connectionType,
            'status': status,
            'note': note.trim(),
            'visibility': visibility,
            'displayNameOptional': displayNameOptional.trim(),
            'sortOrder': sortOrder,
          };
        },
      );

      await tester.tap(find.text('Add relationship'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Label, e.g. Anchor partner',
        ),
        ' Anchor partner ',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Display name (optional)',
        ),
        ' Alex ',
      );
      await tester.tap(find.text('Add to my circle'));
      await tester.pumpAndSettle();

      expect(created?['ownerUid'], 'member-1');
      expect(created?['label'], 'Anchor partner');
      expect(created?['displayNameOptional'], 'Alex');
      expect(created?['connectionType'], 'romantic_partner');
      expect(created?['status'], 'active');
      expect(created?['visibility'], 'matches_only');
      expect(created?['sortOrder'], 0);
    },
  );

  testWidgets(
    'Editor safely falls back from unknown stored enum values',
    (tester) async {
      final legacy = card(
        id: 'legacy-1',
        label: 'Legacy',
        connectionType: 'unknown_type',
        status: 'unknown_status',
        visibility: 'unknown_visibility',
      );

      await pumpManager(
        tester,
        watchCards: (uid) => Stream.value(<Map<String, dynamic>>[legacy]),
      );

      await tester.tap(find.text('Legacy'));
      await tester.pumpAndSettle();

      expect(find.text('Edit relationship'), findsOneWidget);

      final dropdowns = tester
          .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .toList();

      expect(dropdowns[0].initialValue, 'romantic_partner');
      expect(dropdowns[1].initialValue, 'active');
      expect(dropdowns[2].initialValue, 'matches_only');
    },
  );

  testWidgets(
    'Move down submits the exact reordered card list',
    (tester) async {
      List<Map<String, dynamic>>? reordered;
      final cards = <Map<String, dynamic>>[
        card(id: 'card-a', label: 'A'),
        card(id: 'card-b', label: 'B'),
      ];

      await pumpManager(
        tester,
        watchCards: (uid) => Stream.value(cards),
        reorderCards: (next) async {
          reordered = next;
        },
      );

      await tester.tap(
        find.byTooltip('Move down').first,
      );
      await tester.pumpAndSettle();

      expect(
        reordered?.map((item) => item['id']).toList(),
        <String>['card-b', 'card-a'],
      );
    },
  );

  testWidgets(
    'Deactivate uses the exact card ID',
    (tester) async {
      String? deactivated;

      await pumpManager(
        tester,
        watchCards: (uid) => Stream.value(
          <Map<String, dynamic>>[
            card(id: 'card-a', label: 'A'),
          ],
        ),
        deactivateCard: (cardId) async {
          deactivated = cardId;
        },
      );

      await tapMenuAction(tester, 'Deactivate');

      expect(deactivated, 'card-a');
    },
  );

  testWidgets(
    'Delete requires confirmation before destructive action',
    (tester) async {
      var deletes = 0;

      await pumpManager(
        tester,
        watchCards: (uid) => Stream.value(
          <Map<String, dynamic>>[
            card(id: 'card-a', label: 'A'),
          ],
        ),
        deleteCard: (cardId) async {
          deletes += 1;
        },
      );

      await tapMenuAction(tester, 'Delete');

      expect(find.text('Delete relationship card?'), findsOneWidget);
      expect(deletes, 0);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deletes, 0);

      await tapMenuAction(tester, 'Delete');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Delete'),
      );
      await tester.pumpAndSettle();

      expect(deletes, 1);
    },
  );

  testWidgets(
    'Missing card ID fails closed instead of mutating',
    (tester) async {
      var deactivations = 0;
      final malformed = card(id: '', label: 'Broken');

      await pumpManager(
        tester,
        watchCards: (uid) => Stream.value(
          <Map<String, dynamic>>[malformed],
        ),
        deactivateCard: (cardId) async {
          deactivations += 1;
        },
      );

      await tapMenuAction(tester, 'Deactivate');

      expect(deactivations, 0);
      expect(
        find.textContaining('could not be changed'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Failed save remains recoverable in the editor',
    (tester) async {
      var attempts = 0;

      await pumpManager(
        tester,
        watchCards: (uid) => Stream.value(const []),
        createCard: ({
          required ownerUid,
          required label,
          required connectionType,
          required status,
          required note,
          required visibility,
          required displayNameOptional,
          required sortOrder,
        }) async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('temporary failure');
          }
        },
      );

      await tester.tap(find.text('Add relationship'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Label, e.g. Anchor partner',
        ),
        'Partner',
      );

      await tester.tap(find.text('Add to my circle'));
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(
        find.textContaining('Could not save this relationship'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Add to my circle'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to my circle'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text('Add relationship'), findsNothing);
    },
  );

  testWidgets(
    'Stream error exposes a working Retry action',
    (tester) async {
      var watches = 0;

      await pumpManager(
        tester,
        watchCards: (uid) {
          watches += 1;
          if (watches == 1) {
            return Stream<List<Map<String, dynamic>>>.error(
              StateError('temporary load failure'),
            );
          }
          return Stream.value(const []);
        },
      );

      expect(find.text('We could not load your circle'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(watches, greaterThanOrEqualTo(2));
      expect(find.text('Build your circle'), findsOneWidget);
    },
  );
}
