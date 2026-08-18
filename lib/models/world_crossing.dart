class WorldCrossingInsight {
  const WorldCrossingInsight({
    required this.title,
    required this.detail,
    required this.tags,
  });

  final String title;
  final String detail;
  final List<String> tags;
}

class WorldCrossing {
  const WorldCrossing._();

  static List<WorldCrossingInsight> fromProfiles(
    Map<String, dynamic> viewer,
    Map<String, dynamic> other,
  ) {
    final insights = <WorldCrossingInsight>[];

    final sharedInterests = _sharedValues(
      viewer['interests'],
      other['interests'],
      limit: 4,
    );
    if (sharedInterests.isNotEmpty) {
      insights.add(
        WorldCrossingInsight(
          title: 'Shared interests',
          detail: sharedInterests.length == 1
              ? 'You both included this interest in your profiles.'
              : 'You both included these interests in your profiles.',
          tags: sharedInterests,
        ),
      );
    }

    final sharedIntentions = _sharedValues(
      viewer['intentionTags'],
      other['intentionTags'],
      limit: 4,
    );
    if (sharedIntentions.isNotEmpty) {
      insights.add(
        WorldCrossingInsight(
          title: 'Shared intentions',
          detail: sharedIntentions.length == 1
              ? 'You both selected this connection intention.'
              : 'You both selected these connection intentions.',
          tags: sharedIntentions,
        ),
      );
    }

    final viewerStructure = _text(viewer['relationshipStructure']);
    final otherStructure = _text(other['relationshipStructure']);
    if (viewerStructure.isNotEmpty &&
        otherStructure.isNotEmpty &&
        viewerStructure.toLowerCase() == otherStructure.toLowerCase()) {
      insights.add(
        WorldCrossingInsight(
          title: 'Similar relationship style',
          detail: 'You both describe your relationship structure this way.',
          tags: [otherStructure],
        ),
      );
    }

    return insights;
  }

  static List<String> _sharedValues(
    Object? left,
    Object? right, {
    required int limit,
  }) {
    final leftValues = _normalized(left);
    if (leftValues.isEmpty) return const [];

    final rightValues = _normalized(right);
    if (rightValues.isEmpty) return const [];

    final rightKeys = rightValues.map((value) => value.toLowerCase()).toSet();
    final seen = <String>{};
    final shared = <String>[];

    for (final value in leftValues) {
      final key = value.toLowerCase();
      if (!rightKeys.contains(key) || !seen.add(key)) continue;
      shared.add(value);
      if (shared.length == limit) break;
    }

    return shared;
  }

  static List<String> _normalized(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static String _text(Object? raw) => raw is String ? raw.trim() : '';
}
