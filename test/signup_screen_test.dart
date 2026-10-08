import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/auth/signup_screen.dart';

Future<void> pumpSignup(
  WidgetTester tester, {
  SignUpAction? signUpAction,
  VoidCallback? onShowLogin,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SignUpScreen(
        signUpAction: signUpAction,
        onShowLogin: onShowLogin ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> enterSignupFields(
  WidgetTester tester, {
  String email = 'cam@example.com',
  String password = 'password123',
  String confirm = 'password123',
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    email,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Confirm password'),
    confirm,
  );
}

void main() {
  testWidgets(
    'Create account validates required signup fields',
    (tester) async {
      var calls = 0;

      await pumpSignup(
        tester,
        signUpAction: ({required email, required password}) async {
          calls += 1;
        },
      );

      await tester.tap(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(calls, 0);
    },
  );

  testWidgets(
    'Create account rejects mismatched passwords',
    (tester) async {
      var calls = 0;

      await pumpSignup(
        tester,
        signUpAction: ({required email, required password}) async {
          calls += 1;
        },
      );

      await enterSignupFields(
        tester,
        confirm: 'different123',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(calls, 0);
    },
  );

  testWidgets(
    'Create account sends exact entered credentials',
    (tester) async {
      String? receivedEmail;
      String? receivedPassword;

      await pumpSignup(
        tester,
        signUpAction: ({required email, required password}) async {
          receivedEmail = email;
          receivedPassword = password;
        },
      );

      await enterSignupFields(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.pumpAndSettle();

      expect(receivedEmail, 'cam@example.com');
      expect(receivedPassword, 'password123');
    },
  );

  testWidgets(
    'Busy account creation disables competing auth actions',
    (tester) async {
      final gate = Completer<void>();
      var signupCalls = 0;
      var loginCalls = 0;

      await pumpSignup(
        tester,
        signUpAction: ({required email, required password}) {
          signupCalls += 1;
          return gate.future;
        },
        onShowLogin: () {
          loginCalls += 1;
        },
      );

      await enterSignupFields(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.pump();

      final create = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Creating account…'),
      );
      final login = tester.widget<TextButton>(
        find.widgetWithText(
          TextButton,
          'Already have an account? Sign in',
        ),
      );

      expect(create.onPressed, isNull);
      expect(login.onPressed, isNull);
      expect(signupCalls, 1);
      expect(loginCalls, 0);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Create account'), findsOneWidget);
    },
  );

  testWidgets(
    'Firebase signup errors are surfaced to the member',
    (tester) async {
      await pumpSignup(
        tester,
        signUpAction: ({required email, required password}) async {
          throw FirebaseAuthException(
            code: 'email-already-in-use',
            message: 'That email is already in use.',
          );
        },
      );

      await enterSignupFields(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create account'),
      );
      await tester.pumpAndSettle();

      expect(find.text('That email is already in use.'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    },
  );

  testWidgets(
    'Sign-in link invokes its navigation action',
    (tester) async {
      var loginCalls = 0;

      await pumpSignup(
        tester,
        onShowLogin: () {
          loginCalls += 1;
        },
      );

      await tester.tap(
        find.text('Already have an account? Sign in'),
      );
      await tester.pumpAndSettle();

      expect(loginCalls, 1);
    },
  );
}
