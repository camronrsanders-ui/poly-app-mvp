import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp({required String email, required String password}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) return credential;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'onboardingComplete': false,
        'lastActiveAt': FieldValue.serverTimestamp(),
        'accountStatus': 'active',
      }, SetOptions(merge: true));
    } catch (_) {
      // Account creation is two-system work (Auth + Firestore). If the account
      // record cannot be created, roll back the brand-new Auth user so the
      // person is not left signed into an unusable orphan account.
      try {
        await user.delete();
      } catch (_) {
        await _auth.signOut();
      }
      rethrow;
    }
    return credential;
  }

  Future<UserCredential> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user?.uid;
    if (uid == null) return credential;

    try {
      final ref = _firestore.collection('users').doc(uid);
      final account = await ref.get();
      if (!account.exists || account.data()?['accountStatus'] != 'active') {
        await _auth.signOut();
        throw StateError('This Polycircle account is unavailable.');
      }
      await ref.update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Fail closed when the trusted account record cannot be validated.
      if (_auth.currentUser?.uid == uid) {
        await _auth.signOut();
      }
      rethrow;
    }
    return credential;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();
}
