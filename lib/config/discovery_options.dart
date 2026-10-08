const relationshipStructureOptions = <String>[
  'Solo poly',
  'Hierarchical poly',
  'Non-hierarchical poly',
  'Open relationship',
  'Polyfidelity',
  'Relationship anarchy',
  'Monogamish',
  'Exploring',
  'Custom / self-described',
];

const connectionIntentionOptions = <String>[
  'Friendship',
  'Community',
  'Dating',
  'Long-term relationship',
  'Casual connection',
  'Join a polycule',
  'Build / grow a polycule',
  'Exploring / learning',
];

const discoverDistanceOptionsMiles = <int>[5, 10, 20, 30, 50, 100];
const defaultDiscoverDistanceMiles = 20;

int normalizedDiscoverDistanceMiles(Object? value) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return discoverDistanceOptionsMiles.contains(parsed)
      ? parsed!
      : defaultDiscoverDistanceMiles;
}

int? nextDiscoverDistanceMiles(int current) {
  for (final distance in discoverDistanceOptionsMiles) {
    if (distance > current) return distance;
  }
  return null;
}
