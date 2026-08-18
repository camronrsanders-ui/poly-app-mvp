import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/discover/discover_screen.dart';
import 'package:polycircle/services/discover_location_service.dart';
import 'package:polycircle/services/discovery_service.dart';

Map<String, dynamic> _profile(int index) => {
      'uid': 'profile-$index',
      'displayName': 'Profile $index',
      'age': 25 + index,
      'city': 'Fictional City',
      'region': 'FC',
      'headline': 'An emulator-safe nearby world',
      'intentionTags': ['Friendship', 'Dating'],
    };

class _FakeDiscoverRepository implements DiscoverRepository {
  _FakeDiscoverRepository({
    Map<int, int>? candidateCounts,
  }) : candidateCounts = candidateCounts ?? const {20: 2};

  int distanceMiles = 20;
  final Map<int, int> candidateCounts;
  final List<int> savedDistances = [];
  int candidateLoads = 0;
  int locationUpdates = 0;

  @override
  Future<List<Map<String, dynamic>>> loadCandidates({int limit = 30}) async {
    candidateLoads++;
    final count = candidateCounts[distanceMiles] ?? 0;
    return List.generate(count, _profile, growable: false);
  }

  @override
  Future<int> loadDistanceMiles() async => distanceMiles;

  @override
  Future<void> saveDistanceMiles(int distanceMiles) async {
    this.distanceMiles = distanceMiles;
    savedDistances.add(distanceMiles);
  }

  @override
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime observedAt,
  }) async {
    locationUpdates++;
  }
}

class _FakeLocationProvider implements DiscoverLocationProvider {
  _FakeLocationProvider(this.outcome);

  DiscoverLocationOutcome outcome;
  int requests = 0;
  int settingsOpens = 0;

  @override
  Future<void> openSettings(DiscoverLocationStatus status) async {
    settingsOpens++;
  }

  @override
  Future<DiscoverLocationOutcome> requestCurrentLocation() async {
    requests++;
    return outcome;
  }
}

DiscoverLocationOutcome _readyLocation() => DiscoverLocationOutcome(
      DiscoverLocationStatus.ready,
      sample: DiscoverLocationSample(
        latitude: 12.3456,
        longitude: -45.6789,
        accuracyMeters: 250,
        observedAt: DateTime.now(),
      ),
    );

Widget _app(
  _FakeDiscoverRepository repository,
  _FakeLocationProvider location,
) {
  return MaterialApp(
    home: DiscoverScreen(
      discovery: repository,
      locationProvider: location,
      likeUser: (_) async => false,
      passUser: (_) async {},
      onViewProfile: (_) {},
      profileImageBuilder: (_) => const ColoredBox(color: Colors.deepPurple),
    ),
  );
}

void main() {
  testWidgets('20-mile default is saved-state authoritative and loads nearby',
      (tester) async {
    final repository = _FakeDiscoverRepository();
    final location = _FakeLocationProvider(_readyLocation());

    await tester.pumpWidget(_app(repository, location));
    await tester.pumpAndSettle();

    expect(find.text('Within 20 mi'), findsOneWidget);
    expect(repository.locationUpdates, 1);
    expect(repository.candidateLoads, 1);
    expect(find.text('Profile 0, 25'), findsOneWidget);
  });

  testWidgets('changing radius saves and reloads the Orbit population',
      (tester) async {
    final repository = _FakeDiscoverRepository(
      candidateCounts: const {20: 1, 50: 5},
    );
    final location = _FakeLocationProvider(_readyLocation());
    await tester.pumpWidget(_app(repository, location));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('discover-radius-control')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discover-radius-sheet')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('discover-radius-50')));
    await tester.pumpAndSettle();

    expect(repository.savedDistances, [50]);
    expect(repository.candidateLoads, 2);
    expect(find.text('Within 50 mi'), findsOneWidget);
    expect(find.text('1  /  5'), findsOneWidget);
  });

  testWidgets('permission denied is clear, retryable, and links to settings',
      (tester) async {
    final repository = _FakeDiscoverRepository();
    final location = _FakeLocationProvider(
      const DiscoverLocationOutcome(DiscoverLocationStatus.denied),
    );
    await tester.pumpWidget(_app(repository, location));
    await tester.pumpAndSettle();

    expect(find.text('Nearby Discover needs your location'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('discover-location-retry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('discover-location-settings')),
      findsOneWidget,
    );
    expect(repository.candidateLoads, 0);

    await tester.tap(
      find.byKey(const ValueKey('discover-location-settings')),
    );
    await tester.pump();
    expect(location.settingsOpens, 1);
  });

  testWidgets('empty state only widens radius after an explicit action',
      (tester) async {
    final repository = _FakeDiscoverRepository(
      candidateCounts: const {20: 0, 30: 1},
    );
    final location = _FakeLocationProvider(_readyLocation());
    await tester.pumpWidget(_app(repository, location));
    await tester.pumpAndSettle();

    expect(find.text('No new worlds within 20 miles.'), findsOneWidget);
    expect(repository.savedDistances, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('discover-increase-radius')),
    );
    await tester.pumpAndSettle();

    expect(repository.savedDistances, [30]);
    expect(find.text('Profile 0, 25'), findsOneWidget);
  });

  for (final viewport in <Size>[
    const Size(320, 700),
    const Size(390, 800),
    const Size(430, 900),
  ]) {
    testWidgets(
        'full Discover world has no overflow at ${viewport.width.toInt()}x${viewport.height.toInt()}',
        (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeDiscoverRepository(
        candidateCounts: const {20: 10},
      );
      final location = _FakeLocationProvider(_readyLocation());

      await tester.pumpWidget(_app(repository, location));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Within 20 mi'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('discover-world-scroll-view')),
        findsOneWidget,
      );
    });
  }
}
