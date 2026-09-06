import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/profile/profile_detail_screen.dart';
import 'package:polycircle/services/profile_media_service.dart';

const targetProfile = <String, dynamic>{
  'uid': 'target-1',
  'displayName': 'Alex',
};

Future<void> pumpProfile(
  WidgetTester tester,
  ProfileReportAction reportUser, {
  List<VisibleProfilePhoto> photos = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProfileDetailScreen.test(
        profile: targetProfile,
        reportUser: reportUser,
        loadCircle: (_) async => const [],
        loadVisiblePhotos: (_) async => photos,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openReport(WidgetTester tester) async {
  await tester.tap(
    find.byType(PopupMenuButton<String>),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Report'));
  await tester.pumpAndSettle();

  expect(find.text('Report profile'), findsOneWidget);
}

void main() {
  testWidgets(
    'Profile photo carousel exposes position semantics without personal description',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await pumpProfile(
        tester,
        ({
          required String reportedUid,
          required String reason,
          required String details,
          required String contentType,
          String? contentId,
          String? conversationId,
        }) async {},
        photos: [
          VisibleProfilePhoto(
            photoId: 'photo-1',
            url: Uri.parse('https://example.test/photo-1'),
          ),
          VisibleProfilePhoto(
            photoId: 'photo-2',
            url: Uri.parse('https://example.test/photo-2'),
          ),
        ],
      );

      expect(
        find.bySemanticsLabel('Profile photo 1 of 2'),
        findsOneWidget,
      );

      await tester.drag(
        find.byType(PageView),
        const Offset(-400, 0),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.bySemanticsLabel('Profile photo 2 of 2'),
        findsOneWidget,
      );

      semanticsHandle.dispose();
    },
  );

  testWidgets(
    'Profile report requires explicit submission',
    (tester) async {
      var reportCalls = 0;

      await pumpProfile(
        tester,
        ({
          required String reportedUid,
          required String reason,
          required String details,
          required String contentType,
          String? contentId,
          String? conversationId,
        }) async {
          reportCalls += 1;
        },
      );

      await openReport(tester);

      await tester.tap(find.text('Harassment'));
      await tester.pumpAndSettle();

      expect(
        find.text('Threats or violence'),
        findsOneWidget,
      );
      expect(
        find.text('Child safety / underage concern'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Child safety / underage concern'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(reportCalls, 0);
      expect(find.text('Alex'), findsWidgets);
    },
  );

  testWidgets(
    'Profile report submits exact trusted profile context',
    (tester) async {
      var reportCalls = 0;
      String? capturedReportedUid;
      String? capturedReason;
      String? capturedDetails;
      String? capturedContentType;
      String? capturedContentId;
      String? capturedConversationId;

      await pumpProfile(
        tester,
        ({
          required String reportedUid,
          required String reason,
          required String details,
          required String contentType,
          String? contentId,
          String? conversationId,
        }) async {
          reportCalls += 1;
          capturedReportedUid = reportedUid;
          capturedReason = reason;
          capturedDetails = details;
          capturedContentType = contentType;
          capturedContentId = contentId;
          capturedConversationId = conversationId;
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
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 350),
      );

      expect(reportCalls, 1);
      expect(capturedReportedUid, 'target-1');
      expect(capturedReason, 'child_safety');
      expect(capturedDetails, 'Safety details');
      expect(capturedContentType, 'profile');
      expect(capturedContentId, 'target-1');
      expect(capturedConversationId, isNull);
      expect(
        find.text(
          'Report submitted. Thank you for helping keep Polycircle safer.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Failed profile report remains recoverable',
    (tester) async {
      var attempts = 0;

      await pumpProfile(
        tester,
        ({
          required String reportedUid,
          required String reason,
          required String details,
          required String contentType,
          String? contentId,
          String? conversationId,
        }) async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('temporary failure');
          }
        },
      );

      await openReport(tester);
      await tester.tap(find.text('Submit report'));
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 350),
      );

      expect(attempts, 1);
      expect(
        find.text('Could not submit the report right now.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Report submitted. Thank you for helping keep Polycircle safer.',
        ),
        findsNothing,
      );

      var popup = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      expect(popup.enabled, isTrue);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await openReport(tester);
      await tester.tap(find.text('Submit report'));
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 350),
      );

      expect(attempts, 2);
      expect(
        find.text(
          'Report submitted. Thank you for helping keep Polycircle safer.',
        ),
        findsOneWidget,
      );

      popup = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      expect(popup.enabled, isTrue);
    },
  );

  testWidgets(
    'Pending profile report blocks duplicate submission',
    (tester) async {
      final pendingReport = Completer<void>();
      var reportCalls = 0;

      await pumpProfile(
        tester,
        ({
          required String reportedUid,
          required String reason,
          required String details,
          required String contentType,
          String? contentId,
          String? conversationId,
        }) {
          reportCalls += 1;
          return pendingReport.future;
        },
      );

      await openReport(tester);
      await tester.tap(find.text('Submit report'));
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 350),
      );

      expect(reportCalls, 1);

      var popup = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      expect(popup.enabled, isFalse);

      await tester.tap(
        find.byType(PopupMenuButton<String>),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(reportCalls, 1);
      expect(find.text('Report profile'), findsNothing);

      pendingReport.complete();
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 350),
      );

      popup = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      expect(popup.enabled, isTrue);
      expect(reportCalls, 1);
    },
  );
}
