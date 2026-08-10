import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Local Firebase emulators are opt-in so production/staging builds can never
/// silently fall back to localhost. Enable only from a debug launch with:
///
/// flutter run --dart-define=USE_FIREBASE_EMULATORS=true
const bool useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

const String firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

Future<void> configureFirebaseRuntime() async {
  if (!kDebugMode || !useFirebaseEmulators) return;

  await FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
  FirebaseFunctions.instance.useFunctionsEmulator(firebaseEmulatorHost, 5001);
}
