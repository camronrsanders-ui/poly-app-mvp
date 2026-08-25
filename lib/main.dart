import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/firebase_runtime.dart';

Future<void> _configureCrashReporting() async {
  final crashReportingEnabled =
      !kIsWeb && kReleaseMode && !useFirebaseEmulators && !localReleaseSmoke;

  if (kIsWeb) {
    return;
  }

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    crashReportingEnabled,
  );

  if (!crashReportingEnabled) {
    return;
  }

  FlutterError.onError = (details) {
    unawaited(
      FirebaseCrashlytics.instance.recordFlutterFatalError(details),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: true,
      ),
    );
    return true;
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Polycircle handles relationship, safety and chat data. Native Firestore
  // SDKs persist documents to disk by default; use memory-only caching so a
  // later signed-in user on the same device cannot inherit a prior user's local
  // Firestore cache. Web persistence is already opt-in, so keep its default.
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }

  await configureFirebaseRuntime();
  await _configureCrashReporting();
  final localSmokeAppCheck = localReleaseSmoke && useFirebaseEmulators;

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode || localSmokeAppCheck
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );
  runApp(const PolycircleApp());
}
