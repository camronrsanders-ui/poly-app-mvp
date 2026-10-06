import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/main_shell.dart';

class _TestShellPage extends StatelessWidget {
  const _TestShellPage({
    required this.index,
    required this.onFindPeople,
  });

  final int index;
  final VoidCallback onFindPeople;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Test page $index'),
          if (index == 1) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onFindPeople,
              child: const Text('Find people'),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> pumpShell(
  WidgetTester tester, {
  required Map<int, int> buildCounts,
  MainShellSafetyAction? openSafety,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MainShell(
        openSafety: openSafety,
        pageBuilder: (index, onFindPeople) {
          buildCounts[index] = (buildCounts[index] ?? 0) + 1;
          return _TestShellPage(
            index: index,
            onFindPeople: onFindPeople,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectTab(
  WidgetTester tester,
  String label,
) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Discover starts lazy and keeps immersive navigation',
    (tester) async {
      final builds = <int, int>{};

      await pumpShell(
        tester,
        buildCounts: builds,
      );

      expect(find.text('Test page 0'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('discover-dark-navigation')),
        findsOneWidget,
      );
      expect(builds, <int, int>{0: 1});
    },
  );

  testWidgets(
    'Navigation reaches all five primary destinations',
    (tester) async {
      final builds = <int, int>{};

      await pumpShell(
        tester,
        buildCounts: builds,
      );

      await selectTab(tester, 'Connections');
      expect(find.text('Test page 1'), findsOneWidget);

      await selectTab(tester, 'Circle');
      expect(find.text('Test page 2'), findsOneWidget);

      await selectTab(tester, 'Messages');
      expect(find.text('Test page 3'), findsOneWidget);
      expect(find.byTooltip('Safety center'), findsOneWidget);

      await selectTab(tester, 'Profile');
      expect(find.text('Test page 4'), findsOneWidget);
      expect(find.byTooltip('Safety center'), findsOneWidget);
    },
  );

  testWidgets(
    'Security-sensitive tabs rebuild when reselected',
    (tester) async {
      final builds = <int, int>{};

      await pumpShell(
        tester,
        buildCounts: builds,
      );

      const tabs = <String, int>{
        'Connections': 1,
        'Circle': 2,
        'Messages': 3,
        'Profile': 4,
      };

      for (final entry in tabs.entries) {
        await selectTab(tester, entry.key);
        expect(builds[entry.value], 1);

        await selectTab(tester, entry.key);
        expect(builds[entry.value], 2);
      }

      await selectTab(tester, 'Discover');
      await selectTab(tester, 'Discover');

      expect(builds[0], 1);
      expect(
        find.byKey(const ValueKey('discover-dark-navigation')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Connections Find people returns to cached Discover',
    (tester) async {
      final builds = <int, int>{};

      await pumpShell(
        tester,
        buildCounts: builds,
      );

      await selectTab(tester, 'Connections');
      expect(find.text('Test page 1'), findsOneWidget);

      await tester.tap(find.text('Find people'));
      await tester.pumpAndSettle();

      expect(find.text('Test page 0'), findsOneWidget);
      expect(builds[0], 1);
      expect(
        find.byKey(const ValueKey('discover-dark-navigation')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Safety action is functional from non-immersive app bar',
    (tester) async {
      final builds = <int, int>{};
      var safetyCalls = 0;

      await pumpShell(
        tester,
        buildCounts: builds,
        openSafety: () async {
          safetyCalls += 1;
        },
      );

      await selectTab(tester, 'Messages');
      await tester.tap(find.byTooltip('Safety center'));
      await tester.pumpAndSettle();

      expect(safetyCalls, 1);
      expect(find.text('Test page 3'), findsOneWidget);
    },
  );
}
