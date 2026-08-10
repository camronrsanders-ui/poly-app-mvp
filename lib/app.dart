import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config/firebase_runtime.dart';
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
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!kDebugMode || !useFirebaseEmulators) return content;
        return Banner(
          message: 'LOCAL FIREBASE',
          location: BannerLocation.topEnd,
          child: content,
        );
      },
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

  Future<bool> _loadOnboardingStatus(String uid) =>
      _profiles.isOnboardingComplete(uid).timeout(const Duration(seconds: 10));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        if (authSnapshot.hasError) {
          return _SessionErrorScreen(
            onRetry: () => setState(() => _refresh++),
            onSignOut: _auth.signOut,
            debugError: authSnapshot.error,
          );
        }
        final user = authSnapshot.data;
        if (user == null) {
          return _showSignUp
              ? SignUpScreen(onShowLogin: () => setState(() => _showSignUp = false))
              : LoginScreen(onShowSignUp: () => setState(() => _showSignUp = true));
        }
        return FutureBuilder<bool>(
          key: ValueKey('${user.uid}-$_refresh'),
          future: _loadOnboardingStatus(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }
            if (profileSnapshot.hasError) {
              return _SessionErrorScreen(
                onRetry: () => setState(() => _refresh++),
                onSignOut: _auth.signOut,
                debugError: profileSnapshot.error,
              );
            }
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

class _SessionErrorScreen extends StatelessWidget {
  const _SessionErrorScreen({
    required this.onRetry,
    required this.onSignOut,
    this.debugError,
  });

  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;
  final Object? debugError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  'We could not load your account right now.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your connection and try again. You can also sign out and return to the login screen.',
                  textAlign: TextAlign.center,
                ),
                if (kDebugMode && debugError != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    debugError.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
                TextButton(
                  onPressed: () async => onSignOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
