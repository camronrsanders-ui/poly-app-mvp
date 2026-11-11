import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/safety/safety_center_screen.dart';
import 'package:polycircle/theme/app_theme.dart';

void main() {
  const blockedAlex = <String, dynamic>{
    'blockedUid': 'blocked-1',
    'displayName': 'Alex',
  };

  // The exact fixture the live acceptance journey produces: the seed's
  // existing-connection member, blocked by the seeded owner mid-journey.
  const blockedJordan = <String, dynamic>{
    'blockedUid': 'local-jordan',
    'displayName': 'Jordan',
  };

  testWidgets(
    'Safety center explains core consent and access controls',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SafetyCenterScreen()),
      );

      expect(find.text('Safety center'), findsOneWidget);
      expect(find.text('Block at any time'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      for (final heading in [
        'Report concerning behavior',
        'Private media stays gated',
        'Relationship descriptions are not verification',
        'Adults only',
      ]) {
        await tester.scrollUntilVisible(
          find.text(heading),
          300,
          scrollable: scrollable,
        );
        expect(find.text(heading), findsOneWidget);
      }
    },
  );

  testWidgets(
    'Blocked-member flow requires explicit confirmation',
    (tester) async {
      var unblockCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: BlockedMembersScreen(
            loadBlockedUsers: () async => [blockedAlex],
            unblockMember: (_) async {
              unblockCalls += 1;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alex'), findsOneWidget);
      expect(
        find.text('Previous connections and private access stay closed.'),
        findsOneWidget,
      );
      expect(find.text('Unblock'), findsOneWidget);

      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();

      expect(find.text('Unblock Alex?'), findsOneWidget);
      expect(
        find.text(
          'Unblocking allows future eligible interaction, but it does not '
          'restore a previous match, conversation, or private-media access.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(unblockCalls, 0);
      expect(find.text('Alex'), findsOneWidget);
    },
  );

  testWidgets(
    'Confirmed unblock uses exact UID and refreshes the list',
    (tester) async {
      var loadCalls = 0;
      String? unblockedUid;

      Future<List<Map<String, dynamic>>> loadBlockedUsers() async {
        loadCalls += 1;
        return loadCalls == 1 ? [blockedAlex] : const [];
      }

      await tester.pumpWidget(
        MaterialApp(
          home: BlockedMembersScreen(
            loadBlockedUsers: loadBlockedUsers,
            unblockMember: (uid) async {
              unblockedUid = uid;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Unblock'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(unblockedUid, 'blocked-1');
      expect(loadCalls, 2);
      expect(find.text('No blocked members'), findsOneWidget);
      expect(find.text('Alex unblocked.'), findsOneWidget);
    },
  );

  testWidgets(
    'Failed unblock keeps member visible and reports failure',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlockedMembersScreen(
            loadBlockedUsers: () async => [blockedAlex],
            unblockMember: (_) async {
              throw StateError('unblock failed');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Unblock'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('Alex'), findsOneWidget);
      expect(
        find.text('Could not unblock this member right now.'),
        findsOneWidget,
      );
      expect(find.text('Unblock'), findsOneWidget);
    },
  );

  testWidgets(
    'Blocked-member load failure remains recoverable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlockedMembersScreen(
            loadBlockedUsers: () async {
              throw StateError('load failed');
            },
            unblockMember: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load blocked members.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets(
    'Populated blocked-members row fits narrow viewports with the '
    'app theme',
    (tester) async {
      // Regression coverage for PR #70's CI failures at the populated
      // blocked-members checkpoint (101px at the 320dp Android
      // viewport, 73px at the 375dp iOS viewport). The row must hold
      // under the conditions the earlier version of this test missed:
      // the REAL blocked fixture (Jordan, not a short fake name), the
      // app's real theme (custom wide font and text sizes, not the
      // default Material theme), and BOTH CI viewport widths. The name
      // must ellipsize, the subtitle must wrap, and Unblock must stay
      // on screen.
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final size in [const Size(320, 640), const Size(375, 667)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: BlockedMembersScreen(
              loadBlockedUsers: () async => [blockedJordan],
              unblockMember: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Jordan'), findsOneWidget);
        expect(
          find.text('Previous connections and private access stay closed.'),
          findsOneWidget,
        );
        expect(find.text('Unblock'), findsOneWidget);
        expect(
          tester.getRect(find.text('Unblock')).right,
          lessThanOrEqualTo(size.width),
        );

        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  test(
    'BlockedMembersScreen requires both injected callbacks together',
    () {
      expect(
        () => BlockedMembersScreen(
          loadBlockedUsers: () async => const [],
        ),
        throwsAssertionError,
      );
      expect(
        () => BlockedMembersScreen(
          unblockMember: (_) async {},
        ),
        throwsAssertionError,
      );
    },
  );
}
