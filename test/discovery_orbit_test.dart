import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/widgets/discovery_orbit.dart';

Map<String, dynamic> _profile(
  String uid,
  String name, {
  int? age,
  String city = 'Boston',
  String region = 'MA',
  String headline = 'Building intentional connections',
  List<String> intentions = const ['Friendship', 'Dating'],
}) {
  return <String, dynamic>{
    'uid': uid,
    'displayName': name,
    if (age != null) 'age': age,
    'city': city,
    'region': region,
    'headline': headline,
    'intentionTags': intentions,
  };
}

List<Map<String, dynamic>> _profiles(int count) {
  return List<Map<String, dynamic>>.generate(
    count,
    (index) => _profile(
      'profile-$index',
      'Profile $index',
      age: 20 + index,
    ),
    growable: false,
  );
}

DiscoveryOrbit _orbit({
  required List<Map<String, dynamic>> profiles,
  ValueChanged<Map<String, dynamic>>? onViewProfile,
  ValueChanged<Map<String, dynamic>>? onLike,
  ValueChanged<Map<String, dynamic>>? onPass,
  bool Function(String uid)? isActing,
  ValueChanged<int>? onFocusChanged,
  VoidCallback? onRequestMore,
  bool hasMoreProfiles = false,
  bool loadingMore = false,
}) {
  return DiscoveryOrbit(
    profiles: profiles,
    imageBuilder: (uid) => ColoredBox(
      key: ValueKey('image-$uid'),
      color: Colors.blue,
    ),
    onViewProfile: onViewProfile ?? (_) {},
    onLike: onLike ?? (_) {},
    onPass: onPass ?? (_) {},
    isActing: isActing ?? (_) => false,
    onFocusChanged: onFocusChanged,
    onRequestMore: onRequestMore,
    hasMoreProfiles: hasMoreProfiles,
    loadingMore: loadingMore,
  );
}

Widget _testApp(
  DiscoveryOrbit orbit, {
  bool reduceMotion = true,
}) {
  return MaterialApp(
    builder: (context, child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          disableAnimations: reduceMotion,
          accessibleNavigation: reduceMotion,
        ),
        child: child!,
      );
    },
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: orbit,
        ),
      ),
    ),
  );
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('discovery-next-profile')));
  await tester.pumpAndSettle();
}

Future<void> _previous(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('discovery-previous-profile')));
  await tester.pumpAndSettle();
}

void main() {
  group('DiscoveryOrbitMath', () {
    test('large visible windows rotate without making candidates unreachable',
        () {
      final reached = <int>{};

      for (var focus = 0; focus < 25; focus++) {
        final visible = DiscoveryOrbitMath.visibleIndices(
          focus.toDouble(),
          25,
        );
        expect(visible, hasLength(DiscoveryOrbitMath.maxVisibleProfiles));
        expect(visible.toSet(), hasLength(visible.length));
        expect(visible, contains(focus));
        reached.addAll(visible);
      }

      expect(reached, containsAll(List<int>.generate(25, (index) => index)));
    });

    test('continuous feed windows do not wrap old profiles onto the new edge',
        () {
      expect(
        DiscoveryOrbitMath.visibleFeedIndices(0, 45),
        List<int>.generate(8, (index) => index),
      );
      expect(
        DiscoveryOrbitMath.visibleFeedIndices(44, 45),
        List<int>.generate(8, (index) => index + 37),
      );
      expect(DiscoveryOrbitMath.nearestFeedIndex(-1, 45), 0);
      expect(DiscoveryOrbitMath.nearestFeedIndex(46, 45), 44);
    });

    test('wrap and nearest-index math remains valid across either boundary',
        () {
      expect(DiscoveryOrbitMath.wrapIndex(-1, 12), 11);
      expect(DiscoveryOrbitMath.wrapIndex(12, 12), 0);
      expect(DiscoveryOrbitMath.nearestIndex(12.2, 12), 0);
      expect(DiscoveryOrbitMath.nearestIndex(-0.8, 12), 11);
      expect(DiscoveryOrbitMath.distanceToIndex(0, 11, 12), -1);
      expect(DiscoveryOrbitMath.distanceToIndex(11, 0, 12), 1);
    });

    test('depth visuals keep focus dominant without disabling rear profiles',
        () {
      for (final count in <int>[1, 2, 3, 5, 8, 10, 15, 25]) {
        final base = DiscoveryOrbitVisuals.baseNodeSize(count);
        final focused = base *
            DiscoveryOrbitVisuals.nodeScale(
              count: count,
              depth01: 1,
              perspective: 1.44,
              selected: true,
            );
        final rear = base *
            DiscoveryOrbitVisuals.nodeScale(
              count: count,
              depth01: 0,
              perspective: 0.76,
              selected: false,
            );

        expect(focused, greaterThan(rear * 1.7));
        expect(rear, greaterThanOrEqualTo(47));
      }

      expect(
        DiscoveryOrbitVisuals.nodeOpacity(
          depth01: 0,
          selected: false,
        ),
        greaterThanOrEqualTo(0.78),
      );
      expect(
        DiscoveryOrbitVisuals.nodeOpacity(
          depth01: 1,
          selected: true,
        ),
        1,
      );
    });
  });

  testWidgets('one profile remains usable and opens its Profile World',
      (tester) async {
    final viewed = <String>[];

    await tester.pumpWidget(
      _testApp(
        _orbit(
          profiles: [_profile('alex', 'Alex', age: 30)],
          onViewProfile: (profile) => viewed.add(profile['uid'] as String),
        ),
      ),
    );

    expect(find.text('Alex, 30'), findsOneWidget);
    expect(
      find.text('Tap the focused person to enter their world.'),
      findsOneWidget,
    );

    final previous = tester.widget<IconButton>(
      find.byKey(const ValueKey('discovery-previous-profile')),
    );
    final next = tester.widget<IconButton>(
      find.byKey(const ValueKey('discovery-next-profile')),
    );
    expect(previous.onPressed, isNull);
    expect(next.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('discovery-avatar-alex')),
    );
    await tester.pump();

    expect(viewed, ['alex']);
  });

  testWidgets('two profiles rotate correctly with Previous and Next',
      (tester) async {
    await tester.pumpWidget(
      _testApp(
        _orbit(
          profiles: [
            _profile('alex', 'Alex', age: 30),
            _profile('blair', 'Blair', age: 31),
          ],
        ),
      ),
    );

    expect(find.text('Alex, 30'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('discovery-world-preview')), findsOneWidget);
    expect(find.text('WORLD PREVIEW'), findsOneWidget);

    final scene = tester.getRect(
      find.byKey(const ValueKey('discovery-orbit-scene')),
    );
    final alexAvatar = find.byKey(const ValueKey('discovery-avatar-alex'));
    final blairAvatar = find.byKey(const ValueKey('discovery-avatar-blair'));
    final alexCenter = tester.getCenter(alexAvatar);
    final blairCenter = tester.getCenter(blairAvatar);

    // A two-person orbit is deliberately balanced across the center instead
    // of collapsing into a sparse carousel row.
    expect(alexCenter.dy, greaterThan(scene.center.dy));
    expect(blairCenter.dy, lessThan(scene.center.dy));
    expect((alexCenter.dx - scene.center.dx).abs(), lessThan(2));
    expect((blairCenter.dx - scene.center.dx).abs(), lessThan(2));
    expect(tester.getSize(alexAvatar).width,
        greaterThan(tester.getSize(blairAvatar).width));
    expect(
      tester.getSize(alexAvatar).width,
      greaterThan(tester
          .getSize(
            find.byKey(const ValueKey('discovery-you-orb')),
          )
          .width),
    );

    await _next(tester);
    expect(find.text('Blair, 31'), findsOneWidget);

    await _previous(tester);
    expect(find.text('Alex, 30'), findsOneWidget);
  });

  testWidgets('reduced motion snaps focus without inertial flourish',
      (tester) async {
    await tester.pumpWidget(
      _testApp(
        _orbit(profiles: _profiles(3)),
        reduceMotion: true,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('discovery-next-profile')),
    );
    await tester.pump();

    expect(find.text('Profile 1, 21'), findsOneWidget);
  });

  testWidgets('circular drag changes the focused profile', (tester) async {
    await tester.pumpWidget(
      _testApp(
        _orbit(profiles: _profiles(5)),
        reduceMotion: false,
      ),
    );

    final scene = tester.getRect(
      find.byKey(const ValueKey('discovery-orbit-gesture-surface')),
    );
    final start = Offset(scene.center.dx, scene.top + 205);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(-110, -4),
        timeStamp: const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Profile 1, 21'), findsOneWidget);
  });

  testWidgets('mouse drag also rotates the orbit', (tester) async {
    await tester.pumpWidget(
      _testApp(
        _orbit(profiles: _profiles(5)),
      ),
    );

    final scene = tester.getRect(
      find.byKey(const ValueKey('discovery-orbit-gesture-surface')),
    );
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(Offset(scene.center.dx, scene.top + 205));
    await gesture.moveBy(const Offset(-110, -4));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Profile 1, 21'), findsOneWidget);
  });

  testWidgets('tapping a nonfocused profile focuses it before opening it',
      (tester) async {
    final viewed = <String>[];

    await tester.pumpWidget(
      _testApp(
        _orbit(
          profiles: [
            _profile('alex', 'Alex', age: 30),
            _profile('blair', 'Blair', age: 31),
            _profile('casey', 'Casey', age: 32),
          ],
          onViewProfile: (profile) => viewed.add(profile['uid'] as String),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('discovery-avatar-blair')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blair, 31'), findsOneWidget);
    expect(viewed, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('discovery-avatar-blair')),
    );
    await tester.pump();

    expect(viewed, ['blair']);
  });

  testWidgets('Previous and Next expose accessibility labels and change focus',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _testApp(_orbit(profiles: _profiles(3))),
    );

    expect(find.bySemanticsLabel('Previous profile'), findsOneWidget);
    expect(find.bySemanticsLabel('Next profile'), findsOneWidget);
    expect(find.bySemanticsLabel('Profile 1 of 3'), findsOneWidget);

    final previousSize = tester.getSize(
      find.byKey(const ValueKey('discovery-previous-profile')),
    );
    final nextSize = tester.getSize(
      find.byKey(const ValueKey('discovery-next-profile')),
    );
    expect(previousSize.width, greaterThanOrEqualTo(44));
    expect(previousSize.height, greaterThanOrEqualTo(44));
    expect(nextSize.width, greaterThanOrEqualTo(44));
    expect(nextSize.height, greaterThanOrEqualTo(44));

    await _next(tester);
    expect(find.text('Profile 1, 21'), findsOneWidget);
    expect(find.bySemanticsLabel('Profile 2 of 3'), findsOneWidget);

    await _previous(tester);
    expect(find.text('Profile 0, 20'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('profiles beyond the simultaneous visible limit remain reachable',
      (tester) async {
    await tester.pumpWidget(
      _testApp(_orbit(profiles: _profiles(12))),
    );

    expect(
      find.byKey(const ValueKey('discovery-avatar-profile-10')),
      findsNothing,
    );

    for (var index = 1; index <= 6; index++) {
      await _next(tester);
      expect(find.text('Profile $index, ${20 + index}'), findsOneWidget);
    }

    expect(
      find.byKey(const ValueKey('discovery-avatar-profile-10')),
      findsOneWidget,
    );
  });

  testWidgets('forward navigation stops instead of looping at a true feed end',
      (tester) async {
    await tester.pumpWidget(
      _testApp(_orbit(profiles: _profiles(3))),
    );

    await _next(tester);
    await _next(tester);
    expect(find.text('Profile 2, 22'), findsOneWidget);
    final next = tester.widget<IconButton>(
      find.byKey(const ValueKey('discovery-next-profile')),
    );
    expect(next.onPressed, isNull);
    expect(find.text('Profile 0, 20'), findsNothing);
  });

  testWidgets('a requested next page continues from profile 15 to profile 16',
      (tester) async {
    var profiles = _profiles(15);
    var hasMore = true;
    late StateSetter update;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SingleChildScrollView(
                child: _orbit(
                  profiles: profiles,
                  hasMoreProfiles: hasMore,
                  onRequestMore: () {
                    update(() {
                      profiles = _profiles(30);
                      hasMore = false;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    for (var index = 1; index < 15; index++) {
      await _next(tester);
    }
    expect(find.text('Profile 14, 34'), findsOneWidget);
    await _next(tester);
    expect(find.text('Profile 15, 35'), findsOneWidget);
  });

  testWidgets('protected photos own the node surface with antialiased clipping',
      (tester) async {
    await tester.pumpWidget(
      _testApp(_orbit(profiles: _profiles(5))),
    );

    final photo = find.byKey(const ValueKey('photo-profile-uid-profile-0'));
    expect(photo, findsOneWidget);
    final clip = find.ancestor(
      of: photo,
      matching: find.byType(ClipOval),
    );
    expect(clip, findsOneWidget);
    expect(tester.widget<ClipOval>(clip).clipBehavior, Clip.antiAlias);
    expect(find.descendant(of: clip, matching: find.byType(ColoredBox)),
        findsOneWidget);
  });

  testWidgets('25-profile view keeps focus largest and visible nodes legible',
      (tester) async {
    await tester.pumpWidget(
      _testApp(_orbit(profiles: _profiles(25))),
    );

    final frames = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('discovery-frame-profile-');
    });
    expect(frames, findsNWidgets(DiscoveryOrbitMath.maxVisibleProfiles));

    final focused = tester
        .getSize(
          find.byKey(const ValueKey('discovery-frame-profile-0')),
        )
        .width;
    final otherSizes = frames
        .evaluate()
        .map((element) => tester.getSize(find.byWidget(element.widget)).width)
        .where((size) => size != focused)
        .toList(growable: false);

    expect(otherSizes, isNotEmpty);
    expect(otherSizes.every((size) => size < focused), isTrue);
    expect(otherSizes.every((size) => size >= 47), isTrue);
  });

  testWidgets('selected profile information follows focus', (tester) async {
    await tester.pumpWidget(
      _testApp(
        _orbit(
          profiles: [
            _profile(
              'alex',
              'Alex',
              age: 30,
              city: 'Boston',
              headline: 'Coffee and community',
              intentions: const ['Friendship'],
            ),
            _profile(
              'blair',
              'Blair',
              age: 31,
              city: 'Cambridge',
              headline: 'Art and intentional connection',
              intentions: const ['Dating'],
            ),
          ],
        ),
      ),
    );

    expect(find.text('Coffee and community'), findsOneWidget);
    expect(find.text('Friendship'), findsOneWidget);

    await _next(tester);

    expect(find.text('Blair, 31'), findsOneWidget);
    expect(find.text('Cambridge, MA'), findsOneWidget);
    expect(find.text('Art and intentional connection'), findsOneWidget);
    expect(find.text('Dating'), findsOneWidget);
    expect(find.text('Coffee and community'), findsNothing);
  });

  testWidgets('Pass and Connect callbacks receive the focused profile',
      (tester) async {
    final passed = <String>[];
    final liked = <String>[];

    await tester.pumpWidget(
      _testApp(
        _orbit(
          profiles: [
            _profile('alex', 'Alex', age: 30),
            _profile('blair', 'Blair', age: 31),
          ],
          onPass: (profile) => passed.add(profile['uid'] as String),
          onLike: (profile) => liked.add(profile['uid'] as String),
        ),
      ),
    );

    await _next(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('discovery-pass')));
    await tester.tap(find.byKey(const ValueKey('discovery-pass')));
    await tester.tap(find.byKey(const ValueKey('discovery-connect')));
    await tester.pump();

    expect(passed, ['blair']);
    expect(liked, ['blair']);
  });

  testWidgets('acting state disables duplicate profile actions',
      (tester) async {
    final passed = <String>[];
    final liked = <String>[];
    final viewed = <String>[];

    await tester.pumpWidget(
      _testApp(
        _orbit(
          profiles: [_profile('alex', 'Alex', age: 30)],
          onPass: (profile) => passed.add(profile['uid'] as String),
          onLike: (profile) => liked.add(profile['uid'] as String),
          onViewProfile: (profile) => viewed.add(profile['uid'] as String),
          isActing: (_) => true,
        ),
      ),
    );

    expect(find.text('Working…'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('discovery-pass')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('discovery-connect')),
          )
          .onPressed,
      isNull,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('discovery-pass')));
    await tester.tap(find.byKey(const ValueKey('discovery-pass')));
    await tester.tap(find.byKey(const ValueKey('discovery-connect')));
    await tester.tap(
      find.byKey(const ValueKey('discovery-enter-profile-world')),
    );
    await tester.pump();

    expect(passed, isEmpty);
    expect(liked, isEmpty);
    expect(viewed, isEmpty);
  });

  testWidgets(
      'profile removal chooses a valid next candidate without stale state',
      (tester) async {
    var profiles = [
      _profile('alex', 'Alex', age: 30),
      _profile('blair', 'Blair', age: 31),
      _profile('casey', 'Casey', age: 32),
    ];
    late StateSetter update;

    await tester.pumpWidget(
      _testApp(
        _orbit(profiles: profiles),
      ),
    );

    // Rebuild through a stateful parent so the same DiscoveryOrbit state is
    // retained while the focused profile disappears after Pass/Connect.
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _orbit(profiles: profiles),
                ),
              );
            },
          ),
        ),
      ),
    );

    await _next(tester);
    expect(find.text('Blair, 31'), findsOneWidget);

    update(() {
      profiles = [profiles[0], profiles[2]];
    });
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Casey, 32'), findsOneWidget);
    expect(find.bySemanticsLabel('Profile 2 of 2'), findsOneWidget);
  });

  testWidgets('vertical page scroll through orbit center is not captured',
      (tester) async {
    tester.view.physicalSize = const Size(390, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(_orbit(profiles: _profiles(5))),
    );

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    final scene = tester.getRect(
      find.byKey(const ValueKey('discovery-orbit-gesture-surface')),
    );
    final gesture = await tester.startGesture(
      Offset(scene.center.dx, scene.top + 133),
    );
    for (var step = 0; step < 4; step++) {
      await gesture.moveBy(const Offset(0, -45));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(0));
    expect(find.text('Profile 0, 20'), findsOneWidget);
  });

  for (final viewport in <Size>[
    const Size(320, 700),
    const Size(430, 900),
  ]) {
    testWidgets('does not overflow at ${viewport.width.toInt()}px viewport',
        (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _testApp(_orbit(profiles: _profiles(10))),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Profile 0, 20'), findsOneWidget);
    });
  }

  for (final count in <int>[1, 2, 3, 5, 7, 10, 15, 25, 45]) {
    testWidgets('$count-profile synthetic orbit keeps every profile reachable',
        (tester) async {
      await tester.pumpWidget(
        _testApp(_orbit(profiles: _profiles(count))),
      );

      expect(find.text('Profile 0, 20'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (var index = 1; index < count; index++) {
        await _next(tester);
        expect(find.text('Profile $index, ${20 + index}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
