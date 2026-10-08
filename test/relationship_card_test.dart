import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/models/relationship_card.dart';

void main() {
  group('RelationshipCard', () {
    test('round-trips mapped values', () {
      const card = RelationshipCard(
        id: 'card-1',
        ownerUid: 'user-1',
        label: 'Anchor partner',
        connectionType: 'anchor_partner',
        displayNameOptional: 'Alex',
        status: 'active',
        note: 'Together for years',
        visibility: 'matches_only',
        sortOrder: 2,
        isActive: true,
      );

      final mapped = card.toMap();
      final restored = RelationshipCard.fromMap(card.id, mapped);

      expect(restored.id, card.id);
      expect(restored.ownerUid, card.ownerUid);
      expect(restored.label, card.label);
      expect(restored.connectionType, card.connectionType);
      expect(restored.displayNameOptional, card.displayNameOptional);
      expect(restored.status, card.status);
      expect(restored.note, card.note);
      expect(restored.visibility, card.visibility);
      expect(restored.sortOrder, card.sortOrder);
      expect(restored.isActive, card.isActive);
    });

    test('uses privacy-conscious defaults for missing fields', () {
      final card = RelationshipCard.fromMap('card-2', const {});

      expect(card.id, 'card-2');
      expect(card.ownerUid, isEmpty);
      expect(card.connectionType, 'custom');
      expect(card.status, 'active');
      expect(card.visibility, 'matches_only');
      expect(card.sortOrder, 0);
      expect(card.isActive, isTrue);
    });
  });
}
