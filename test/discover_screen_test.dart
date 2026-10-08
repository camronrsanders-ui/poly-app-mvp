import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/discover/discover_screen.dart';
import 'package:polycircle/services/discover_location_service.dart';
import 'package:polycircle/services/discovery_service.dart';
import 'package:polycircle/services/profile_media_service.dart';
import 'package:polycircle/widgets/discovery_orbit.dart';

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
    this.duplicateAtPageBoundary = false,
    this.nextPageGate,
  }) : candidateCounts = candidateCounts ?? const {20: 2};

  int distanceMiles = 20;
  final Map<int, int> candidateCounts;
  final bool duplicateAtPageBoundary;
  final Future<void>? nextPageGate;
  final List<int> savedDistances = [];
  final List<String?> requestedCursors = [];
  int candidateLoads = 0;
  int locationUpdates = 0;

  @override
  Future<DiscoverPage> loadCandidates({
    int limit = discoverPageSize,
    String? cursor,
  }) async {
    candidateLoads++;
    requestedCursors.add(cursor);
    if (cursor != null && nextPageGate != null) await nextPageGate;
    final count = candidateCounts[distanceMiles] ?? 0;
    final pageIndex = cursor == null ? 0 : int.parse(cursor.split('-').last);
    final start = pageIndex * limit;
    final end = start + limit < count ? start + limit : count;
    final profiles = start >= count
        ? const <Map<String, dynamic>>[]
        : List.generate(
            end - start,
            (index) => _profile(start + index),
            growable: true,
          );
    if (duplicateAtPageBoundary && pageIndex > 0 && profiles.isNotEmpty) {
      profiles[0] = _profile(start - 1);
    }
    final hasMore = end < count;
    return DiscoverPage(
      profiles: profiles,
      nextCursor: hasMore ? 'page-${pageIndex + 1}' : null,
      hasMore: hasMore,
    );
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
  _FakeLocationProvider location, {
  Future<bool> Function(String uid)? likeUser,
  Future<void> Function(String uid)? passUser,
  Widget Function(String uid)? profileImageBuilder,
  Future<List<VisibleProfilePhoto>> Function(String uid)? profilePhotosLoader,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: true,
        accessibleNavigation: true,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: DiscoverScreen(
        discovery: repository,
        locationProvider: location,
        likeUser: likeUser ?? (_) async => false,
        passUser: passUser ?? (_) async {},
        onViewProfile: (_) {},
        profileImageBuilder: profileImageBuilder ??
            (profilePhotosLoader == null
                ? (_) => const ColoredBox(color: Colors.deepPurple)
                : null),
        profilePhotosLoader: profilePhotosLoader,
      ),
    ),
  );
}

Future<void> _nextProfiles(WidgetTester tester, int count) async {
  for (var step = 0; step < count; step++) {
    await tester.tap(
      find.byKey(const ValueKey('discovery-next-profile')),
    );
    await tester.pumpAndSettle();
  }
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

  testWidgets('first page is 15 and profile 12 prefetches the next 15',
      (tester) async {
    final repository = _FakeDiscoverRepository(
      candidateCounts: const {20: 45},
    );
    final location = _FakeLocationProvider(_readyLocation());

    await tester.pumpWidget(_app(repository, location));
    await tester.pumpAndSettle();

    expect(repository.requestedCursors, [null]);
    expect(find.text('1 / 15+'), findsOneWidget);

    await _nextProfiles(tester, 10);
    expect(repository.candidateLoads, 1);
    expect(find.text('11 / 15+'), findsOneWidget);

    await _nextProfiles(tester, 1);
    expect(repository.requestedCursors, [null, 'page-1']);
    expect(find.text('12 / 30+'), findsOneWidget);
  });

  testWidgets('rotation continues through profiles 16, 31, and 45',
      (tester) async {
    final repository = _FakeDiscoverRepository(
      candidateCounts: const {20: 45},
    );
    final location = _FakeLocationProvider(_readyLocation());
    await tester.pumpWidget(_app(repository, location));
    await tester.pumpAndSettle();

    await _nextProfiles(tester, 15);
    expect(find.text('Profile 15, 40'), findsOneWidget);
    expect(find.text('16 / 30+'), findsOneWidget);

    await _nextProfiles(tester, 11);
    expect(repository.requestedCursors, [null, 'page-1', 'page-2']);
    expect(find.text('27 / 45'), findsOneWidget);

    await _nextProfiles(tester, 4);
    expect(find.text('Profile 30, 55'), findsOneWidget);
    await _nextProfiles(tester, 14);
    expect(find.text('Profile 44, 69'), findsOneWidget);
    expect(find.text('45 / 45'), findsOneWidget);
    final next = tester.widget<IconButton>(
      find.byKey(const ValueKey('discovery-next-profile')),
    );
    expect(next.onPressed, isNull);
    await tester.drag(
      find.byKey(const ValueKey('discover-world-scroll-view')),
      const Offset(0, -1800),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('You’ve explored the nearby worlds available right now.'),
      findsOneWidget,
    );
  });

  testWidgets('a delayed prefetch advances naturally after the page boundary',
      (tester) async {
    final gate = Completer<void>();
    final repository = _FakeDiscoverRepository(
      candidateCounts: const {20: 30},
      nextPageGate: gate.future,
    );
    final location = _FakeLocationProvider(_readyLocation());
    await tester.pumpWidget(_app(repository, location));
    await tester.pumpAndSettle();

    for (var step = 0; step < 14; step++) {
      await tester.tap(
        find.byKey(const ValueKey('discovery-next-profile')),
      );
      await tester.pump(const Duration(milliseconds: 520));
    }
    expect(find.text('Profile 14, 39'), findsOneWidget);
    expect(repository.candidateLoads, 2);

    await tester.tap(
      find.byKey(const ValueKey('discovery-next-profile')),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('discovery-next-profile')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Profile 15, 40'), findsOneWidget);
    expect(find.text('16 / 30'), findsOneWidget);
  });

  testWidgets('duplicate UIDs in a later response are not appended twice',
      (tester) async {
    final repository = _FakeDiscoverRepository(
      candidateCounts: const {20: 31},
      duplicateAtPageBoundary: true,
    );
    final location = _FakeLocationProvider(_readyLocation());
    await tester.pumpWidget(_app(repository, location));
    await tester.pumpAndSettle();

    await _nextProfiles(tester, 11);
    expect(find.text('12 / 29+'), findsOneWidget);
    await _nextProfiles(tester, 4);
    expect(find.text('Profile 16, 41'), findsOneWidget);
    expect(find.text('16 / 29+'), findsOneWidget);
  });

  testWidgets('profile photos are loaded only for the near-visible window',
      (tester) async {
    final repository = _FakeDiscoverRepository(
      candidateCounts: const {20: 45},
    );
    final location = _FakeLocationProvider(_readyLocation());
    final requestedPhotos = <String>{};
    await tester.pumpWidget(
      _app(
        repository,
        location,
        profileImageBuilder: (uid) {
          requestedPhotos.add(uid);
          return const ColoredBox(color: Colors.deepPurple);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedPhotos.length,
        lessThanOrEqualTo(DiscoveryOrbitMath.maxVisibleProfiles));
    expect(requestedPhotos.length, lessThan(discoverPageSize));
  });

  testWidgets('protected photo metadata requests are serialized',
      (tester) async {
    final repository = _FakeDiscoverRepository(
      candidateCounts: const {20: 15},
    );
    final location = _FakeLocationProvider(_readyLocation());
    final requestedPhotos = <String>[];
    final requests = <Completer<List<VisibleProfilePhoto>>>[];

    await tester.pumpWidget(
      _app(
        repository,
        location,
        profilePhotosLoader: (uid) {
          requestedPhotos.add(uid);
          final request = Completer<List<VisibleProfilePhoto>>();
          requests.add(request);
          return request.future;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(requestedPhotos, ['profile-0']);
    requests.first.complete(const <VisibleProfilePhoto>[]);
    await tester.pump();
    await tester.pump();

    expect(requestedPhotos.length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    requests[1].complete(const <VisibleProfilePhoto>[]);
    await tester.pump();
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
    expect(repository.requestedCursors, [null, null]);
    expect(find.text('Within 50 mi'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets('pull-to-refresh starts a fresh cursor session', (tester) async {
    final repository = _FakeDiscoverRepository(
      candidateCounts: const {20: 20},
    );
    final location = _FakeLocationProvider(_readyLocation());
    await tester.pumpWidget(_app(repository, location));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('discover-world-scroll-view')),
      const Offset(0, 350),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedCursors, [null, null]);
    expect(find.text('1 / 15+'), findsOneWidget);
  });

  for (final action in ['Pass', 'Connect']) {
    testWidgets('$action at the first batch edge keeps the next profile stable',
        (tester) async {
      final repository = _FakeDiscoverRepository(
        candidateCounts: const {20: 30},
      );
      final location = _FakeLocationProvider(_readyLocation());
      final actedOn = <String>[];
      await tester.pumpWidget(
        _app(
          repository,
          location,
          passUser: (uid) async {
            actedOn.add(uid);
          },
          likeUser: (uid) async {
            actedOn.add(uid);
            return false;
          },
        ),
      );
      await tester.pumpAndSettle();
      await _nextProfiles(tester, 14);
      expect(find.text('Profile 14, 39'), findsOneWidget);

      final actionKey = action == 'Pass'
          ? const ValueKey('discovery-pass')
          : const ValueKey('discovery-connect');
      await tester.drag(
        find.byKey(const ValueKey('discover-world-scroll-view')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(actionKey));
      await tester.pumpAndSettle();

      expect(actedOn, ['profile-14']);
      expect(find.text('Profile 15, 40'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
