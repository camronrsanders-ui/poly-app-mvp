import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/models/world_crossing.dart';

void main() {
  group('WorldCrossing', () {
    test('returns factual shared interests and intentions', () {
      final insights = WorldCrossing.fromProfiles(
        const {
          'interests': ['Travel', 'Cooking', 'Books'],
          'intentionTags': ['Friendship', 'Dating'],
          'relationshipStructure': 'Solo poly',
        },
        const {
          'interests': ['travel', 'Music', 'Books'],
          'intentionTags': ['Dating', 'Community'],
          'relationshipStructure': 'Solo poly',
        },
      );

      expect(insights.map((item) => item.title), [
        'Shared interests',
        'Shared intentions',
        'Similar relationship style',
      ]);
      expect(insights[0].tags, ['Travel', 'Books']);
      expect(insights[1].tags, ['Dating']);
      expect(insights[2].tags, ['Solo poly']);
    });

    test('does not invent compatibility when profiles do not overlap', () {
      final insights = WorldCrossing.fromProfiles(
        const {
          'interests': ['Cooking'],
          'intentionTags': ['Friendship'],
          'relationshipStructure': 'Solo poly',
        },
        const {
          'interests': ['Running'],
          'intentionTags': ['Dating'],
          'relationshipStructure': 'Relationship anarchy',
        },
      );

      expect(insights, isEmpty);
    });

    test('ignores malformed values and limits repeated tags', () {
      final insights = WorldCrossing.fromProfiles(
        const {
          'interests': ['Travel', 'travel', '', 42, 'Books', 'Music', 'Art'],
        },
        const {
          'interests': ['TRAVEL', 'Books', 'Music', 'Art', 'Cooking'],
        },
      );

      expect(insights, hasLength(1));
      expect(insights.single.tags, ['Travel', 'Books', 'Music', 'Art']);
    });
  });
}
