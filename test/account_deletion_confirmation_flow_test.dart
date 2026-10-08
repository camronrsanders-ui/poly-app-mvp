import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/profile/profile_screen.dart';

Future<void> pumpDeletionLauncher(
  WidgetTester tester, {
  required ValueChanged<bool> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              final result = await confirmPermanentAccountDeletion(context);
              onResult(result);
            },
            child: const Text('Start deletion'),
          ),
        ),
      ),
    ),
  );
}

Future<void> openDeletionFlow(WidgetTester tester) async {
  await tester.tap(find.text('Start deletion'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'first account deletion confirmation can be cancelled',
    (tester) async {
      bool? result;

      await pumpDeletionLauncher(
        tester,
        onResult: (value) => result = value,
      );

      await openDeletionFlow(tester);

      expect(find.text('Delete your account?'), findsOneWidget);
      expect(
        find.text(
          'This permanently removes your profile and account-owned data. '
          'It cannot be undone.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Final confirmation'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'final account deletion confirmation can be cancelled',
    (tester) async {
      bool? result;

      await pumpDeletionLauncher(
        tester,
        onResult: (value) => result = value,
      );

      await openDeletionFlow(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Final confirmation'), findsOneWidget);
      expect(
        find.text(
          'Type DELETE to permanently delete your Polycircle account.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lowercase delete does not pass permanent deletion confirmation',
    (tester) async {
      bool? result;

      await pumpDeletionLauncher(
        tester,
        onResult: (value) => result = value,
      );

      await openDeletionFlow(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exact DELETE passes permanent deletion confirmation',
    (tester) async {
      bool? result;

      await pumpDeletionLauncher(
        tester,
        onResult: (value) => result = value,
      );

      await openDeletionFlow(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'permanent deletion confirmation preserves trim semantics',
    (tester) async {
      bool? result;

      await pumpDeletionLauncher(
        tester,
        onResult: (value) => result = value,
      );

      await openDeletionFlow(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        '  DELETE  ',
      );
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
