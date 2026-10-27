import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/content/learn_content.dart';
import 'package:polycircle/screens/learn/learn_screen.dart';
import 'package:polycircle/screens/main_shell.dart';

Future<void> pumpLearn(WidgetTester tester) async {
  // Tall viewport: the Get Help card leads the page and, with its
  // call/text action buttons, runs ~1100px tall before the support
  // card and glossary, so a default 800x600 surface never reaches
  // the glossary.
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: LearnScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Learn opens with the Get Help card first, above the glossary',
    (tester) async {
      await pumpLearn(tester);

      expect(find.text(LearnContent.helpCardHeading), findsOneWidget);
      for (final resource in LearnContent.crisisResources) {
        expect(find.text(resource.name), findsOneWidget);
        expect(find.text(resource.contact), findsOneWidget);
      }

      final helpTop =
          tester.getTopLeft(find.text(LearnContent.helpCardHeading)).dy;
      final searchTop = tester
          .getTopLeft(find.byKey(const ValueKey('learn-glossary-search')))
          .dy;
      expect(helpTop < searchTop, isTrue);
    },
  );

  testWidgets(
    'Glossary search filters terms live',
    (tester) async {
      await pumpLearn(tester);

      await tester.enterText(
        find.byKey(const ValueKey('learn-glossary-search')),
        'kitchen table',
      );
      await tester.pumpAndSettle();

      expect(find.text('Kitchen table polyamory'), findsOneWidget);
      expect(find.text('Compersion'), findsNothing);
      expect(find.text('Metamour'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('learn-glossary-search')),
        'zzzz-no-such-term',
      );
      await tester.pumpAndSettle();

      expect(find.text('Kitchen table polyamory'), findsNothing);
      expect(
        find.textContaining('No terms match yet'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Category chips narrow the glossary',
    (tester) async {
      await pumpLearn(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Feelings'));
      await tester.pumpAndSettle();

      expect(find.text('Compersion'), findsOneWidget);
      expect(find.text('New relationship energy (NRE)'), findsOneWidget);
      expect(find.text('Metamour'), findsNothing);
      expect(find.text('Polyamory'), findsNothing);
    },
  );

  testWidgets(
    'A term expands to show its definition and example',
    (tester) async {
      await pumpLearn(tester);

      final metamour = LearnContent.glossary.firstWhere(
        (term) => term.term == 'Metamour',
      );

      await tester.enterText(
        find.byKey(const ValueKey('learn-glossary-search')),
        'metamour',
      );
      await tester.pumpAndSettle();

      expect(find.text('Metamour'), findsOneWidget);
      expect(find.text(metamour.definition), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Metamour'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Metamour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Metamour'));
      await tester.pumpAndSettle();

      expect(find.text(metamour.definition), findsOneWidget);
      expect(find.text('Example: ${metamour.example}'), findsOneWidget);
    },
  );

  testWidgets(
    'Learning paths and the book shelf render their content',
    (tester) async {
      await pumpLearn(tester);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Working through jealousy'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Working through jealousy'), findsOneWidget);
      expect(find.text('Jealousy as a smoke detector'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Polysecure'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Polysecure'), findsOneWidget);
      expect(
        find.text(
          'Read this if… you want to understand attachment styles and '
          'build emotional safety across multiple bonds.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Main shell reaches Learn from the tab and the app-bar help action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            pageBuilder: (index, onFindPeople) => Center(
              child: Text('Shell page $index'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Learn').last);
      await tester.pumpAndSettle();
      expect(find.text('Shell page 5'), findsOneWidget);

      await tester.tap(find.text('Messages').last);
      await tester.pumpAndSettle();
      expect(find.text('Shell page 3'), findsOneWidget);
      expect(find.byTooltip('Get help & learn'), findsOneWidget);

      await tester.tap(find.byTooltip('Get help & learn'));
      await tester.pumpAndSettle();
      expect(find.text('Shell page 5'), findsOneWidget);
    },
  );

  group('Actionable resources', () {
    test('crisis resources carry the right call and text URIs', () {
      final byName = {
        for (final resource in LearnContent.crisisResources)
          resource.name: resource,
      };

      expect(
        byName['988 Suicide & Crisis Lifeline']!.actions.single.uri,
        'tel:988',
      );
      expect(
        byName['Crisis Text Line']!.actions.single.uri,
        'sms:741741?body=HOME',
      );
      expect(
        byName['The Trevor Project']!.actions.single.uri,
        'tel:+18664887386',
      );
      expect(
        byName['Trans Lifeline']!.actions.single.uri,
        'tel:+18775658860',
      );

      final hotline = byName['National Domestic Violence Hotline']!;
      expect(
        hotline.actions.map((action) => action.uri),
        containsAll(['tel:+18007997233', 'sms:88788?body=START']),
      );

      // Every crisis resource offers at least one tap-to-act action,
      // and the contact itself always stays visible as text.
      for (final resource in LearnContent.crisisResources) {
        expect(resource.actions, isNotEmpty, reason: resource.name);
        expect(resource.contact, isNotEmpty, reason: resource.name);
      }
    });

    test('books and support entries link out over https', () {
      for (final book in LearnContent.books) {
        expect(book.libraryUrl, startsWith('https://'), reason: book.title);
      }
      // Four of the five books resolve in the OverDrive catalog. The
      // Relationship Escalator book is not carried there (verified
      // 2026-10-27), so its library action points at WorldCat.
      expect(
        LearnContent.books
            .where((book) => book.libraryUrl.contains('overdrive.com'))
            .length,
        4,
      );
      expect(
        LearnContent.books
            .singleWhere(
              (book) => book.title.contains('Relationship Escalator'),
            )
            .libraryUrl,
        startsWith('https://search.worldcat.org/'),
      );

      for (final group in LearnContent.supportGroups) {
        for (final entry in group.entries) {
          expect(entry.url, startsWith('https://'), reason: entry.name);
        }
      }
    });
  });
}
