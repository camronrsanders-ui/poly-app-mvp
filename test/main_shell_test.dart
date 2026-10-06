import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/main_shell.dart';

Widget _page(String label) => Center(child: Text(label));

void main() {
  testWidgets(
    'main shell lazy-loads injected tabs and refreshes sensitive tabs on re-entry',
    (tester) async {
      final builds = List<int>.filled(5, 0);

      final builders = List<WidgetBuilder>.generate(
        5,
        (index) => (_) {
          builds[index] += 1;
          return _page('page-$index');
        },
        growable: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell.test(
            pageBuilders: builders,
            safetyCenterBuilder: (_) => _page('safety-page'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('page-0'), findsOneWidget);
      expect(builds, [1, 0, 0, 0, 0]);

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();

      expect(find.text('page-3'), findsOneWidget);
      expect(builds, [1, 0, 0, 1, 0]);

      await tester.tap(find.byIcon(Icons.chat_bubble));
      await tester.pumpAndSettle();

      expect(find.text('page-3'), findsOneWidget);
      expect(builds, [1, 0, 0, 2, 0]);
    },
  );

  testWidgets(
    'all five destinations route to the intended page',
    (tester) async {
      final builders = List<WidgetBuilder>.generate(
        5,
        (index) => (_) => _page('page-$index'),
        growable: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell.test(
            pageBuilders: builders,
            safetyCenterBuilder: (_) => _page('safety-page'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Connections'), findsOneWidget);
      expect(find.text('Circle'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.people_alt_outlined));
      await tester.pumpAndSettle();
      expect(find.text('page-1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.hub_outlined));
      await tester.pumpAndSettle();
      expect(find.text('page-2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();
      expect(find.text('page-3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(find.text('page-4'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.explore_outlined));
      await tester.pumpAndSettle();
      expect(find.text('page-0'), findsOneWidget);
    },
  );

  testWidgets(
    'safety center action opens the configured safety destination',
    (tester) async {
      final builders = List<WidgetBuilder>.generate(
        5,
        (index) => (_) => _page('page-$index'),
        growable: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell.test(
            pageBuilders: builders,
            safetyCenterBuilder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Test safety')),
              body: _page('safety-page'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Safety center'), findsOneWidget);
      await tester.tap(find.byTooltip('Safety center'));
      await tester.pumpAndSettle();

      expect(find.text('Test safety'), findsOneWidget);
      expect(find.text('safety-page'), findsOneWidget);
    },
  );
}
