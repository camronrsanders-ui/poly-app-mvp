import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/compliance/compliance_gate_screen.dart';
import 'package:polycircle/services/age_assurance_service.dart';

Future<void> pumpCompliance(
  WidgetTester tester, {
  required Future<void> Function() onSignOut,
  AdultSignalRequester? requestAdultSignal,
  PolicyAcceptanceRecorder? recordPolicyAcceptance,
  BirthDatePicker? birthDatePicker,
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: ComplianceGateScreen(
        onSignOut: onSignOut,
        requestAdultSignal: requestAdultSignal,
        recordPolicyAcceptance: recordPolicyAcceptance,
        birthDatePicker: birthDatePicker,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DateTime adultBirthDate() {
  final now = DateTime.now();
  return DateTime(now.year - 25, now.month, now.day);
}

DateTime minorBirthDate() {
  final now = DateTime.now();
  return DateTime(now.year - 17, now.month, now.day);
}

Future<void> tapVisibleText(
  WidgetTester tester,
  String label, {
  bool settle = true,
}) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> chooseBirthDate(WidgetTester tester) async {
  await tapVisibleText(tester, 'Date of birth');
}

Future<void> acceptPolicies(WidgetTester tester) async {
  await tapVisibleText(
    tester,
    'I am 18+ and accept the Terms of Use',
  );
  await tapVisibleText(
    tester,
    'I accept the Community Guidelines',
  );
}

void main() {
  testWidgets(
    'Sign out uses the supplied session action',
    (tester) async {
      var calls = 0;

      await pumpCompliance(
        tester,
        onSignOut: () async {
          calls += 1;
        },
      );

      await tapVisibleText(tester, 'Sign out');

      expect(calls, 1);
    },
  );

  testWidgets(
    'Continue requires a date of birth',
    (tester) async {
      await pumpCompliance(
        tester,
        onSignOut: () async {},
      );

      await tapVisibleText(tester, 'Verify & continue');

      expect(
        find.text('Choose your date of birth to continue.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Under-18 date blocks access and offers sign-in return',
    (tester) async {
      var signOutCalls = 0;

      await pumpCompliance(
        tester,
        onSignOut: () async {
          signOutCalls += 1;
        },
        birthDatePicker: (context, currentBirthDate) async {
          return minorBirthDate();
        },
      );

      await chooseBirthDate(tester);
      await tapVisibleText(tester, 'Verify & continue');

      expect(find.text('Adult-only access'), findsOneWidget);
      expect(
        find.text(
          'Polycircle is only available to adults age 18 and older.',
        ),
        findsOneWidget,
      );

      await tapVisibleText(tester, 'Return to sign in');

      expect(signOutCalls, 1);
    },
  );

  testWidgets(
    'Adult date still requires both policy acceptances',
    (tester) async {
      await pumpCompliance(
        tester,
        onSignOut: () async {},
        birthDatePicker: (context, currentBirthDate) async {
          return adultBirthDate();
        },
      );

      await chooseBirthDate(tester);
      await tapVisibleText(tester, 'Verify & continue');

      expect(
        find.text(
          'You must accept both the Terms of Use and Community Guidelines '
          'before creating or sharing content.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Confirmed adult records exact bounded assurance status',
    (tester) async {
      String? method;
      String? status;

      await pumpCompliance(
        tester,
        onSignOut: () async {},
        birthDatePicker: (context, currentBirthDate) async {
          return adultBirthDate();
        },
        requestAdultSignal: () async {
          return const AgeAssuranceResult(
            decision: AgeAssuranceDecision.adult,
            method: 'play_age_signals',
            platformStatus: 'adult_range',
          );
        },
        recordPolicyAcceptance: ({
          required ageAssuranceMethod,
          required ageSignalStatus,
        }) async {
          method = ageAssuranceMethod;
          status = ageSignalStatus;
        },
      );

      await chooseBirthDate(tester);
      await acceptPolicies(tester);
      await tapVisibleText(
        tester,
        'Verify & continue',
        settle: false,
      );
      await tester.pump();

      expect(method, 'play_age_signals');
      expect(status, 'adult:adult_range');
    },
  );

  testWidgets(
    'Verification-required signal does not record acceptance',
    (tester) async {
      var records = 0;

      await pumpCompliance(
        tester,
        onSignOut: () async {},
        birthDatePicker: (context, currentBirthDate) async {
          return adultBirthDate();
        },
        requestAdultSignal: () async {
          return const AgeAssuranceResult(
            decision: AgeAssuranceDecision.verificationRequired,
            method: 'play_age_signals',
            regulatedRegion: true,
          );
        },
        recordPolicyAcceptance: ({
          required ageAssuranceMethod,
          required ageSignalStatus,
        }) async {
          records += 1;
        },
      );

      await chooseBirthDate(tester);
      await acceptPolicies(tester);
      await tapVisibleText(tester, 'Verify & continue');

      expect(records, 0);
      expect(
        find.textContaining('requires age verification'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Successful acceptance stays guarded until the session gate advances',
    (tester) async {
      final gate = Completer<void>();

      await pumpCompliance(
        tester,
        onSignOut: () async {},
        birthDatePicker: (context, currentBirthDate) async {
          return adultBirthDate();
        },
        requestAdultSignal: () async {
          return const AgeAssuranceResult(
            decision: AgeAssuranceDecision.adult,
            method: 'play_age_signals',
            platformStatus: 'adult_range',
          );
        },
        recordPolicyAcceptance: ({
          required ageAssuranceMethod,
          required ageSignalStatus,
        }) {
          return gate.future;
        },
      );

      await chooseBirthDate(tester);
      await acceptPolicies(tester);
      await tapVisibleText(
        tester,
        'Verify & continue',
        settle: false,
      );

      final checking = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Checking…'),
      );
      expect(checking.onPressed, isNull);

      gate.complete();
      await tester.pump();
      await tester.pump();

      final stillChecking = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Checking…'),
      );
      expect(stillChecking.onPressed, isNull);
    },
  );
}
