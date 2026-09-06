import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Local Firebase emulators are opt-in.
///
/// Debug builds may use them directly. Optimized release-mode emulator testing
/// additionally requires POLYCIRCLE_LOCAL_RELEASE_SMOKE=true so a normal
/// production release can never silently route to local Firebase.
const bool useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

const bool localReleaseSmoke = bool.fromEnvironment(
  'POLYCIRCLE_LOCAL_RELEASE_SMOKE',
  defaultValue: false,
);

const String firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

Future<void> configureFirebaseRuntime() async {
  if (!useFirebaseEmulators) {
    if (localReleaseSmoke) {
      throw StateError(
        'POLYCIRCLE_LOCAL_RELEASE_SMOKE requires USE_FIREBASE_EMULATORS=true.',
      );
    }
    return;
  }

  if (!kDebugMode && !localReleaseSmoke) {
    throw StateError(
      'Release emulator routing requires '
      'POLYCIRCLE_LOCAL_RELEASE_SMOKE=true.',
    );
  }

  await FirebaseAuth.instance.useAuthEmulator(firebaseEmulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8080);
  FirebaseFunctions.instance.useFunctionsEmulator(firebaseEmulatorHost, 5001);
}
