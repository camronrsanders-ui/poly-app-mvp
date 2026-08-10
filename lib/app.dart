import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'config/firebase_runtime.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/account_service.dart';
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

        // Watch the trusted account document rather than checking it only once
        // at login. A suspension, ban, deletion pause, or onboarding completion
        // therefore removes or advances the app shell as soon as Firestore
        // delivers the authoritative change. Backend rules remain the final
        // enforcement boundary even if the device is temporarily offline.
        return StreamBuilder<Map<String, dynamic>?>(
          key: ValueKey('${user.uid}-$_refresh'),
          stream: _profiles.watchAccount(user.uid),
          builder: (context, accountSnapshot) {
            if (accountSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }
            if (accountSnapshot.hasError) {
              return _SessionErrorScreen(
                onRetry: () => setState(() => _refresh++),
                onSignOut: _auth.signOut,
                debugError: accountSnapshot.error,
              );
            }

            final account = accountSnapshot.data;
            if (account == null) {
              return _SessionErrorScreen(
                onRetry: () => setState(() => _refresh++),
                onSignOut: _auth.signOut,
                debugError: StateError('Account record is unavailable.'),
              );
            }

            final status = account['accountStatus']?.toString() ?? '';
            final deletionPending = status == 'paused' && account['deletionRequestedAt'] != null;
            if (deletionPending) {
              return _DeletionRecoveryScreen(
                onFinished: _auth.signOut,
                onSignOut: _auth.signOut,
              );
            }
            if (status != 'active') {
              return _AccountUnavailableScreen(onSignOut: _auth.signOut);
            }
            if (account['onboardingComplete'] != true) {
              return const OnboardingScreen(onComplete: _noop);
            }
            return const MainShell();
          },
        );
      },
    );
  }
}

void _noop() {}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

class _DeletionRecoveryScreen extends StatefulWidget {
  const _DeletionRecoveryScreen({required this.onFinished, required this.onSignOut});

  final Future<void> Function() onFinished;
  final Future<void> Function() onSignOut;

  @override
  State<_DeletionRecoveryScreen> createState() => _DeletionRecoveryScreenState();
}

class _DeletionRecoveryScreenState extends State<_DeletionRecoveryScreen> {
  final _account = AccountService();
  bool _working = false;
  String? _error;

  Future<void> _finishDeletion() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await _account.deleteMyAccount();
      await widget.onFinished();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = 'Deletion is still pending. Please try again. If your sign-in is no longer recent, sign out and sign back in first.';
      });
      if (kDebugMode) debugPrint('Pending account deletion retry failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_forever_outlined, size: 60),
              const SizedBox(height: 16),
              Text('Account deletion is pending', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              const Text(
                'Your account is paused and cannot use Polycircle while deletion cleanup is unfinished. Finish the cleanup below or sign out and sign back in to refresh your security check.',
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _working ? null : _finishDeletion,
                child: _working
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Finish deleting my account'),
              ),
              TextButton(
                onPressed: _working ? null : () async => widget.onSignOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AccountUnavailableScreen extends StatelessWidget {
  const _AccountUnavailableScreen({required this.onSignOut});
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              Text('This account is unavailable', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'This account cannot use Polycircle in its current state.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton(
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
