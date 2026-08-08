import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'theme/app_theme.dart';

class PolycircleApp extends StatelessWidget {
  const PolycircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Polycircle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _SessionGate(),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();
  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  final _auth = AuthService();
  final _profiles = ProfileService();
  bool _showSignUp = false;
  int _refresh = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        final user = authSnapshot.data;
        if (user == null) {
          return _showSignUp
              ? SignUpScreen(onShowLogin: () => setState(() => _showSignUp = false))
              : LoginScreen(onShowSignUp: () => setState(() => _showSignUp = true));
        }
        return FutureBuilder<bool>(
          key: ValueKey('${user.uid}-$_refresh'),
          future: _profiles.isOnboardingComplete(user.uid),
          builder: (context, profileSnapshot) {
            if (!profileSnapshot.hasData) return const _LoadingScreen();
            if (profileSnapshot.data != true) {
              return OnboardingScreen(onComplete: () => setState(() => _refresh++));
            }
            return const MainShell();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}
