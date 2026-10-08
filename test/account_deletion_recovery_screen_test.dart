import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/app.dart';

void main() {
  testWidgets(
    'Deletion recovery explains the paused account state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeletionRecoveryScreen(
            deleteAccount: () async {},
            onFinished: () async {},
            onSignOut: () async {},
          ),
        ),
      );

      expect(
        find.text('Account deletion is pending'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your account is paused and cannot use Polycircle while deletion '
          'cleanup is unfinished. Finish the cleanup below or sign out and '
          'sign back in to refresh your security check.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Finish deleting my account'),
        findsOneWidget,
      );
      expect(find.text('Sign out'), findsOneWidget);
    },
  );

  testWidgets(
    'Successful deletion retry finishes exactly once',
    (tester) async {
      var deleteCalls = 0;
      var finishedCalls = 0;
      var signOutCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DeletionRecoveryScreen(
            deleteAccount: () async {
              deleteCalls += 1;
            },
            onFinished: () async {
              finishedCalls += 1;
            },
            onSignOut: () async {
              signOutCalls += 1;
            },
          ),
        ),
      );

      await tester.tap(
        find.text('Finish deleting my account'),
      );
      await tester.pump();
      await tester.pump();

      expect(deleteCalls, 1);
      expect(finishedCalls, 1);
      expect(signOutCalls, 0);
    },
  );

  testWidgets(
    'Pending deletion disables duplicate retry and sign out',
    (tester) async {
      final pendingDelete = Completer<void>();
      var deleteCalls = 0;
      var finishedCalls = 0;
      var signOutCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DeletionRecoveryScreen(
            deleteAccount: () {
              deleteCalls += 1;
              return pendingDelete.future;
            },
            onFinished: () async {
              finishedCalls += 1;
            },
            onSignOut: () async {
              signOutCalls += 1;
            },
          ),
        ),
      );

      await tester.tap(
        find.text('Finish deleting my account'),
      );
      await tester.pump();

      expect(deleteCalls, 1);

      final finishButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      final signOutButton = tester.widget<TextButton>(
        find.byType(TextButton),
      );

      expect(finishButton.onPressed, isNull);
      expect(signOutButton.onPressed, isNull);
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
      );

      await tester.pump(
        const Duration(milliseconds: 100),
      );

      expect(deleteCalls, 1);
      expect(signOutCalls, 0);

      pendingDelete.complete();
      await tester.pump();
      await tester.pump();

      expect(deleteCalls, 1);
      expect(finishedCalls, 1);
      expect(signOutCalls, 0);
    },
  );

  testWidgets(
    'Failed deletion retry remains recoverable',
    (tester) async {
      var attempts = 0;
      var finishedCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DeletionRecoveryScreen(
            deleteAccount: () async {
              attempts += 1;
              if (attempts == 1) {
                throw StateError('retryable failure');
              }
            },
            onFinished: () async {
              finishedCalls += 1;
            },
            onSignOut: () async {},
          ),
        ),
      );

      await tester.tap(
        find.text('Finish deleting my account'),
      );
      await tester.pump();
      await tester.pump();

      expect(attempts, 1);
      expect(finishedCalls, 0);
      expect(
        find.text(
          'Deletion is still pending. Please try again. '
          'If your sign-in is no longer recent, sign out '
          'and sign back in first.',
        ),
        findsOneWidget,
      );

      final retryButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );

      expect(retryButton.onPressed, isNotNull);
      expect(
        find.text('Finish deleting my account'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Finish deleting my account'),
      );
      await tester.pump();
      await tester.pump();

      expect(attempts, 2);
      expect(finishedCalls, 1);
    },
  );

  testWidgets(
    'Sign out remains a separate recovery action',
    (tester) async {
      var deleteCalls = 0;
      var finishedCalls = 0;
      var signOutCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DeletionRecoveryScreen(
            deleteAccount: () async {
              deleteCalls += 1;
            },
            onFinished: () async {
              finishedCalls += 1;
            },
            onSignOut: () async {
              signOutCalls += 1;
            },
          ),
        ),
      );

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump();

      expect(signOutCalls, 1);
      expect(deleteCalls, 0);
      expect(finishedCalls, 0);
    },
  );
}
