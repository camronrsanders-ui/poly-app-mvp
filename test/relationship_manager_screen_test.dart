import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/circle/relationship_manager_screen.dart';
import 'package:polycircle/services/relationship_card_service.dart';

class _FakeRelationshipCardService implements RelationshipCardService {
  _FakeRelationshipCardService(this.cards);

  List<Map<String, dynamic>> cards;
  Map<String, dynamic>? created;
  Map<String, dynamic>? updated;
  String? deactivatedId;
  String? deletedId;
  List<String>? reorderedIds;

  @override
  Stream<List<Map<String, dynamic>>> watchCards(String ownerUid) =>
      Stream.value(cards);

  @override
  Future<void> createCard({
    required String ownerUid,
    required String label,
    required String connectionType,
    required String status,
    required String note,
    required String visibility,
    String displayNameOptional = '',
    required int sortOrder,
  }) async {
    created = <String, dynamic>{
      'ownerUid': ownerUid,
      'label': label,
      'connectionType': connectionType,
      'status': status,
      'note': note,
      'visibility': visibility,
      'displayNameOptional': displayNameOptional,
      'sortOrder': sortOrder,
    };
  }

  @override
  Future<void> updateCard({
    required String cardId,
    required String ownerUid,
    required Map<String, dynamic> values,
  }) async {
    updated = <String, dynamic>{
      'cardId': cardId,
      'ownerUid': ownerUid,
      'values': Map<String, dynamic>.from(values),
    };
  }

  @override
  Future<void> deactivateCard(String cardId) async {
    deactivatedId = cardId;
  }

  @override
  Future<void> deleteCard(String cardId) async {
    deletedId = cardId;
  }

  @override
  Future<void> reorderCards(List<Map<String, dynamic>> cards) async {
    reorderedIds = cards.map((card) => card['id'] as String).toList();
  }
}

Future<void> pumpManager(
  WidgetTester tester,
  _FakeRelationshipCardService service,
) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RelationshipManagerScreen.test(
          uid: 'owner-1',
          service: service,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> card(
  String id,
  String label, {
  int sortOrder = 0,
}) =>
    <String, dynamic>{
      'id': id,
      'ownerUid': 'owner-1',
      'label': label,
      'connectionType': 'romantic_partner',
      'displayNameOptional': '',
      'status': 'active',
      'note': '',
      'visibility': 'matches_only',
      'sortOrder': sortOrder,
      'isActive': true,
    };

void main() {
  testWidgets(
    'empty Circle add action creates a relationship with the exact owner',
    (tester) async {
      final service = _FakeRelationshipCardService(
        const <Map<String, dynamic>>[],
      );
      await pumpManager(tester, service);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Add relationship'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add relationship'), findsWidgets);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Anchor partner',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Add to my circle'),
      );
      await tester.pumpAndSettle();

      expect(service.created, isNotNull);
      expect(service.created!['ownerUid'], 'owner-1');
      expect(service.created!['label'], 'Anchor partner');
      expect(service.created!['connectionType'], 'romantic_partner');
      expect(service.created!['status'], 'active');
      expect(service.created!['visibility'], 'matches_only');
      expect(service.created!['sortOrder'], 0);
    },
  );

  testWidgets(
    'tapping a relationship edits that exact card',
    (tester) async {
      final service = _FakeRelationshipCardService([
        card('card-a', 'Partner'),
      ]);
      await pumpManager(tester, service);

      await tester.tap(find.text('Partner'));
      await tester.pumpAndSettle();

      expect(find.text('Edit relationship'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Nesting partner',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Save changes'),
      );
      await tester.pumpAndSettle();

      expect(service.updated, isNotNull);
      expect(service.updated!['cardId'], 'card-a');
      expect(service.updated!['ownerUid'], 'owner-1');
      final values = service.updated!['values'] as Map<String, dynamic>;
      expect(values['label'], 'Nesting partner');
    },
  );

  testWidgets(
    'move controls send the intended reordered card sequence',
    (tester) async {
      final service = _FakeRelationshipCardService([
        card('card-a', 'First', sortOrder: 0),
        card('card-b', 'Second', sortOrder: 1),
      ]);
      await pumpManager(tester, service);

      final moveDown = find.byTooltip('Move down');
      expect(moveDown, findsNWidgets(2));

      await tester.tap(moveDown.first);
      await tester.pumpAndSettle();

      expect(service.reorderedIds, ['card-b', 'card-a']);
    },
  );

  testWidgets(
    'deactivate menu action targets the selected card',
    (tester) async {
      final service = _FakeRelationshipCardService([
        card('card-a', 'Partner'),
      ]);
      await pumpManager(tester, service);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      expect(service.deactivatedId, 'card-a');
    },
  );

  testWidgets(
    'delete requires confirmation and then deletes the selected card',
    (tester) async {
      final service = _FakeRelationshipCardService([
        card('card-a', 'Partner'),
      ]);
      await pumpManager(tester, service);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete relationship card?'), findsOneWidget);
      expect(service.deletedId, isNull);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Delete'),
      );
      await tester.pumpAndSettle();

      expect(service.deletedId, 'card-a');
    },
  );
}
