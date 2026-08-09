import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountService {
  AccountService({FirebaseFunctions? functions, FirebaseAuth? auth})
      : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<void> deleteMyAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No signed-in user.');

    final callable = _functions.httpsCallable('deleteMyAccount');
    final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'confirmation': 'DELETE',
    });
    if (result.data['deleted'] != true) {
      throw StateError('Account deletion did not complete.');
    }
  }
}
