import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/messages/chat_screen.dart';
import 'package:polycircle/theme/app_theme.dart';

Future<void> pumpReportLauncher(
  WidgetTester tester, {
  String? messageId,
  String otherDisplayName = 'Alex',
  ThemeData? theme,
  required ChatReportAction reportUser,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              await showChatReportFlow(
                context: context,
                reportedUid: 'target-1',
                otherDisplayName: otherDisplayName,
                conversationId: 'conversation-1',
                messageId: messageId,
                reportUser: reportUser,
              );
            },
            child: const Text('Open report'),
          ),
        ),
      ),
    ),
  );
}

Future<void> openReport(WidgetTester tester) async {
  await tester.tap(find.text('Open report'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'chat message report can be cancelled without submitting',
    (tester) async {
      var calls = 0;

      await pumpReportLauncher(
        tester,
        messageId: 'message-1',
        reportUser: ({
          required String reportedUid,
          required String reason,
          required String details,
          required String contentType,
          String? contentId,
          String? conversationId,
        }) async {
          calls += 1;
        },
      );

      await openReport(tester);

      expect(find.text('Report this message'), findsOneWidget);
      expect(
        find.textContaining(
          'The report will include a protected reference to this message',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Harassment'));
      await tester.pumpAndSettle();

      expect(find.text('Threats or violence'), findsOneWidget);
      expect(
        find.text('Child safety / underage concern'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat message report submits exact trusted message context',
    (tester) async {
      Map<String, Object?>? payload;

      await pumpReportLauncher(
        tester,
        messageId: 'message-1',
        reportUser: ({
          required String reportedUid,
          required String reason,
          required String details,
          required String contentType,
          String? contentId,
          String? conversationId,
        }) async {
          payload = <String, Object?>{
            'reportedUid': reportedUid,
            'reason': reason,
            'details': details,
            'contentType': contentType,
            'contentId': contentId,
            'conversationId': conversationId,
          };
        },
      );

      await openReport(tester);

      await tester.tap(find.text('Harassment'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Child safety / underage concern'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        '  Safety details  ',
      );

      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      expect(
        payload,
        <String, Object?>{
          'reportedUid': 'target-1',
          'reason': 'child_safety',
          'details': '  Safety details  ',
          'contentType': 'message',
          'contentId': 'message-1',
          'conversationId': 'conversation-1',
        },
      );

      expect(
        find.text(
          'Report submitted. Thank you for helping protect the community.',
        ),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat account report omits message context',
    (tester) async {
      Map<String, Object?>? payload;

      await pumpReportLauncher(
        tester,
        reportUser: ({
          required String reportedUid,
          required String reason,
          required String details,
          required String contentType,
          String? contentId,
          String? conversationId,
        }) async {
          payload = <String, Object?>{
            'reportedUid': reportedUid,
            'contentType': contentType,
            'contentId': contentId,
            'conversationId': conversationId,
          };
        },
      );

      await openReport(tester);

      expect(find.text('Report Alex'), findsOneWidget);

      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      expect(
        payload,
        <String, Object?>{
          'reportedUid': 'target-1',
          'contentType': 'account',
          'contentId': null,
          'conversationId': null,
        },
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat report failure is truthful and later retry succeeds',
    (tester) async {
      var attempts = 0;

      Future<void> reportUser({
        required String reportedUid,
        required String reason,
        required String details,
        required String contentType,
        String? contentId,
        String? conversationId,
      }) async {
        attempts += 1;
        if (attempts == 1) {
          throw StateError('transient failure');
        }
      }

      await pumpReportLauncher(
        tester,
        messageId: 'message-1',
        reportUser: reportUser,
      );

      await openReport(tester);
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(
        find.text('Could not submit the report right now.'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await openReport(tester);
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(
        find.text(
          'Report submitted. Thank you for helping protect the community.',
        ),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    },
  );

  // Regression coverage for PR #70's live-journey failure: in the real
  // app (custom wide font, floating snackbar theme) at CI device
  // widths, the UI-16 segment's report submit was followed — at the
  // next screenshot checkpoint — by "A RenderFlex overflowed by 101
  // pixels" (Android 320dp) / "73 pixels" (iOS 375dp). The tests above
  // use the default theme on an 800x600 surface, where every layout in
  // this flow fits; these variants reproduce the live conditions:
  // AppTheme, the seeded name 'Jordan', and the two CI viewport sizes.
  // The dialog (reason dropdown) and the confirmation snackbar are
  // both exercised, in the journey's order.
  for (final entry in <String, Size>{
    'Android 320dp': const Size(320, 640),
    'iOS 375dp': const Size(375, 667),
  }.entries) {
    testWidgets(
      'chat report flow fits a narrow viewport (${entry.key}) '
      'with the app theme',
      (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpReportLauncher(
          tester,
          otherDisplayName: 'Jordan',
          theme: AppTheme.light,
          reportUser: ({
            required String reportedUid,
            required String reason,
            required String details,
            required String contentType,
            String? contentId,
            String? conversationId,
          }) async {},
        );

        await openReport(tester);

        expect(find.text('Report Jordan'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Submit report'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Report submitted. Thank you for helping protect the '
            'community.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
