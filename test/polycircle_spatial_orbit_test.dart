import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/widgets/polycircle_spatial_orbit.dart';

class _Person {
  const _Person(this.id, this.name);

  final String id;
  final String name;
}

const _ana = _Person('ana', 'Ana');
const _bo = _Person('bo', 'Bo');
const _cy = _Person('cy', 'Cy');
const _di = _Person('di', 'Di');

Widget _testApp(
  Widget child, {
  bool reduceMotion = false,
}) {
  return MaterialApp(
    builder: (context, appChild) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          disableAnimations: reduceMotion,
          accessibleNavigation: reduceMotion,
        ),
        child: appChild!,
      );
    },
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          child: child,
        ),
      ),
    ),
  );
}

PolycircleSpatialOrbit<_Person> _orbit({
  required List<_Person> people,
  required List<String> focusedLog,
  PolycircleSpatialOrbitController? controller,
}) {
  return PolycircleSpatialOrbit<_Person>(
    items: people,
    itemId: (person) => person.id,
    labelBuilder: (person) => person.name,
    avatarBuilder: (context, person, focused) => SizedBox.expand(
      key: ValueKey<String>('avatar-${person.id}'),
      child: const ColoredBox(
        color: Colors.blueGrey,
      ),
    ),
    onFocused: (person) => focusedLog.add(person.id),
    onOpen: (_) {},
    controller: controller,
    height: 400,
  );
}

Offset _orbitCenter(WidgetTester tester) {
  final topLeft = tester.getTopLeft(
    find.byType(
      PolycircleSpatialOrbit<_Person>,
    ),
  );

  return topLeft + const Offset(200, 172);
}

Offset _pointAt(
  Offset center,
  double theta,
) {
  // Mirrors the orbit's own pointer correction (dy scaled by 1.65),
  // so equal theta steps are equal angular steps.
  return Offset(
    center.dx + math.cos(theta) * 120,
    center.dy + math.sin(theta) * 120 / 1.65,
  );
}

/// Drags around the ring by [totalRadians] in [steps] even angular
/// steps, building release velocity like a real fling would. The
/// drag starts between nodes so no node's tap recognizer competes
/// with the orbit's pan recognizer.
Future<void> _dragArc(
  WidgetTester tester, {
  required double totalRadians,
  required int steps,
}) async {
  final center = _orbitCenter(tester);

  const startTheta = .4;

  final gesture = await tester.startGesture(
    _pointAt(center, startTheta),
  );

  for (var step = 1; step <= steps; step++) {
    await gesture.moveTo(
      _pointAt(center, startTheta + totalRadians * step / steps),
    );
    await tester.pump(
      const Duration(milliseconds: 16),
    );
  }

  await gesture.up();
}

void main() {
  group('SpatialOrbitVisuals', () {
    test('sparse populations get larger nodes', () {
      expect(SpatialOrbitVisuals.baseNodeSize(1), 108);
      expect(SpatialOrbitVisuals.baseNodeSize(2), 92);
      expect(SpatialOrbitVisuals.baseNodeSize(3), 76);
      expect(SpatialOrbitVisuals.baseNodeSize(12), 76);
    });

    test('a pair is depth-balanced so neither person dominates', () {
      expect(
        SpatialOrbitVisuals.balancedDepth01(
          renderedCount: 2,
          depth01: 1,
        ),
        closeTo(.675, 1e-9),
      );
      expect(
        SpatialOrbitVisuals.balancedDepth01(
          renderedCount: 2,
          depth01: 0,
        ),
        closeTo(.325, 1e-9),
      );
      expect(
        SpatialOrbitVisuals.balancedDepth01(
          renderedCount: 5,
          depth01: 1,
        ),
        1,
      );
    });
  });

  testWidgets(
    'a single person renders portrait-forward',
    (tester) async {
      final log = <String>[];

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana],
            focusedLog: log,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final singleSize = tester.getSize(
        find.byKey(
          const ValueKey('avatar-ana'),
        ),
      );

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana, _bo, _cy],
            focusedLog: log,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trioSize = tester.getSize(
        find.byKey(
          const ValueKey('avatar-ana'),
        ),
      );

      expect(singleSize.width, greaterThan(trioSize.width + 30));
    },
  );

  testWidgets(
    'focus follows the same person when the roster is reordered',
    (tester) async {
      final log = <String>[];

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana, _bo, _cy],
            focusedLog: log,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('avatar-cy'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cy'), findsOneWidget);
      expect(log.last, 'cy');

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_cy, _ana, _bo],
            focusedLog: log,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cy kept focus through the reorder; Ana never silently
      // inherited it.
      expect(find.text('Cy'), findsOneWidget);
      expect(find.text('Ana'), findsNothing);
    },
  );

  testWidgets(
    'removing the focused person at the end falls back to the new last person',
    (tester) async {
      final log = <String>[];

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana, _bo, _cy],
            focusedLog: log,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('avatar-cy'),
        ),
      );
      await tester.pumpAndSettle();

      expect(log.last, 'cy');

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana, _bo],
            focusedLog: log,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bo'), findsOneWidget);
      expect(log.last, 'bo');
    },
  );

  testWidgets(
    'removing a focused person mid-roster falls back to their successor',
    (tester) async {
      final log = <String>[];

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana, _bo, _cy],
            focusedLog: log,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('avatar-bo'),
        ),
      );
      await tester.pumpAndSettle();

      expect(log.last, 'bo');

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana, _cy],
            focusedLog: log,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cy'), findsOneWidget);
      expect(log.last, 'cy');
    },
  );

  testWidgets(
    'reduced motion focuses a tapped person immediately',
    (tester) async {
      final log = <String>[];

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana, _bo, _cy],
            focusedLog: log,
          ),
          reduceMotion: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('avatar-cy'),
        ),
      );
      await tester.pump();

      expect(find.text('Cy'), findsOneWidget);
      expect(log.last, 'cy');
    },
  );

  testWidgets(
    'full motion animates a tapped focus change over time',
    (tester) async {
      final log = <String>[];

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana, _bo, _cy],
            focusedLog: log,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey('avatar-cy'),
        ),
      );
      await tester.pump();

      // One frame in, the camera is still travelling: Ana remains
      // focused until the animation carries focus to Cy.
      expect(find.text('Ana'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Cy'), findsOneWidget);
    },
  );

  testWidgets(
    'reduced motion drag ends without inertial travel',
    (tester) async {
      final log = <String>[];

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana, _bo, _cy, _di],
            focusedLog: log,
          ),
          reduceMotion: true,
        ),
      );
      await tester.pumpAndSettle();

      // A short, fast drag: the hand moves focus less than one
      // step, and reduced motion means the release adds nothing.
      await _dragArc(
        tester,
        totalRadians: -.6,
        steps: 3,
      );
      await tester.pump(
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana'), findsOneWidget);
    },
  );

  testWidgets(
    'full motion drag keeps travelling after release',
    (tester) async {
      final log = <String>[];

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana, _bo, _cy, _di],
            focusedLog: log,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _dragArc(
        tester,
        totalRadians: -.6,
        steps: 3,
      );
      await tester.pump(
        const Duration(milliseconds: 300),
      );

      // The same gesture that stays on Ana under reduced motion
      // has flung focus onward: the inertia-driven travel after
      // release carries the ring well past Ana's slot. (Where a
      // multi-revolution fling finally settles is phase-dependent,
      // so this asserts the departure, not a landing spot.)
      expect(find.text('Ana'), findsNothing);
    },
  );

  testWidgets(
    'every person stays reachable beyond the render cap',
    (tester) async {
      final people = List<_Person>.generate(
        30,
        (index) => _Person('p$index', 'Person $index'),
        growable: false,
      );
      final log = <String>[];
      final controller = PolycircleSpatialOrbitController();

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: people,
            focusedLog: log,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final renderedAvatars = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith('avatar-'),
      );

      // Rendering stays bounded at the cap…
      expect(renderedAvatars, findsNWidgets(12));
      expect(
        find.byKey(
          const ValueKey('avatar-p29'),
        ),
        findsNothing,
      );

      controller.focusItem('p29');
      await tester.pumpAndSettle();

      // …but person 30 is fully reachable and now rendered.
      expect(log.last, 'p29');
      expect(find.text('Person 29'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('avatar-p29'),
        ),
        findsOneWidget,
      );
      expect(renderedAvatars, findsNWidgets(12));
    },
  );

  testWidgets(
    'backgrounding mid-gesture leaves a settled orbit',
    (tester) async {
      final log = <String>[];

      await tester.pumpWidget(
        _testApp(
          _orbit(
            people: const [_ana, _bo, _cy, _di],
            focusedLog: log,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = _orbitCenter(tester);

      final gesture = await tester.startGesture(
        _pointAt(center, 0),
      );

      await gesture.moveTo(
        _pointAt(center, -.2),
      );
      await tester.pump(
        const Duration(milliseconds: 16),
      );

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );

      await gesture.up();
      await tester.pumpAndSettle();

      // No stuck drag and no fling on return: the orbit settled
      // exactly where the interrupted gesture left it.
      expect(find.text('Ana'), findsOneWidget);
    },
  );
}
