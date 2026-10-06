import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/auth/login_screen.dart';

Future<void> pumpLogin(
  WidgetTester tester, {
  LoginAction? loginAction,
  PasswordResetAction? passwordResetAction,
  VoidCallback? onShowSignUp,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LoginScreen(
        loginAction: loginAction,
        passwordResetAction: passwordResetAction,
        onShowSignUp: onShowSignUp ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> enterCredentials(
  WidgetTester tester, {
  String email = 'cam@example.com',
  String password = 'password123',
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    email,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
}

void main() {
  testWidgets(
    'sign in validates required credentials before invoking action',
    (tester) async {
      var calls = 0;

      await pumpLogin(
        tester,
        loginAction: ({required email, required password}) async {
          calls += 1;
        },
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(calls, 0);
    },
  );

  testWidgets('sign in sends exact entered credentials', (tester) async {
    await pumpLogin(
      tester,
      loginAction: ({
        required String email,
        required String password,
      }) async {
        // Capture verbatim screen input. Trimming remains an AuthService\n        // concern.
        expect(email, 'cam@example.com');
        expect(password, 'password123');
      },
    );

    await enterCredentials(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Reaching here without an expectation failure proves the exact action ran.
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
  });

  testWidgets(
    'busy sign-in disables all competing auth actions',
    (tester) async {
      final gate = Completer<void>();
      var loginCalls = 0;
      var signUpCalls = 0;

      await pumpLogin(
        tester,
        loginAction: ({required email, required password}) {
          loginCalls += 1;
          return gate.future;
        },
        onShowSignUp: () {
          signUpCalls += 1;
        },
      );

      await enterCredentials(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Signing in…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Signing in…'),
        ).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Forgot password?'),
        ).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'New to Polycircle? Create account'),
        ).onPressed,
        isNull,
      );

      expect(loginCalls, 1);
      expect(signUpCalls, 0);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
    },
  );

  testWidgets(
    'forgot password requires email before invoking reset',
    (tester) async {
      var resets = 0;

      await pumpLogin(
        tester,
        passwordResetAction: (email) async {
          resets += 1;
        },
      );

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter your email first, then tap Forgot password.'),
        findsOneWidget,
      );
      expect(resets, 0);
    },
  );

  testWidgets(
    'forgot password uses entered email and confirms success',
    (tester) async {
      String? resetEmail;

      await pumpLogin(
        tester,
        passwordResetAction: (email) async {
          resetEmail = email;
        },
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'cam@example.com',
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(resetEmail, 'cam@example.com');
      expect(find.text('Password reset email sent.'), findsOneWidget);
    },
  );

  testWidgets(
    'Firebase auth errors are surfaced to the member',
    (tester) async {
      await pumpLogin(
        tester,
        loginAction: ({required email, required password}) async {
          throw FirebaseAuthException(
            code: 'invalid-credential',
            message: 'Invalid email or password.',
          );
        },
      );

      await enterCredentials(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    },
  );

  testWidgets(
    'create-account link invokes its navigation action',
    (tester) async {
      var signUpCalls = 0;

      await pumpLogin(
        tester,
        onShowSignUp: () {
          signUpCalls += 1;
        },
      );

      await tester.tap(find.text('New to Polycircle? Create account'));
      await tester.pumpAndSettle();

      expect(signUpCalls, 1);
    },
  );
}
