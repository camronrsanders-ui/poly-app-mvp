import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'ugc_text_policy.dart';

class MessagingService {
  MessagingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    return uid;
  }

  Future<String> ensureConversation(String otherUid) async {
    final currentUid = _requireUid();
    if (currentUid == otherUid) {
      throw ArgumentError('Cannot create a conversation with yourself.');
    }
    final callable = _functions.httpsCallable('createConversation');
    final result =
        await callable.call<Map<String, dynamic>>({'otherUid': otherUid});
    final id = result.data['conversationId'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('Conversation was not created.');
    }
    return id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
      String conversationId) {
    _requireUid();
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('messageType', isEqualTo: 'text')
        .orderBy('createdAt')
        .limitToLast(100)
        .snapshots();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> loadOlderMessages({
    required String conversationId,
    required DocumentSnapshot<Map<String, dynamic>> before,
    int limit = 30,
  }) {
    _requireUid();
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('messageType', isEqualTo: 'text')
        .orderBy('createdAt')
        .endBeforeDocument(before)
        .limitToLast(limit)
        .get();
  }

  Future<void> sendMessage(
      {required String conversationId, required String text}) async {
    final senderUid = _requireUid();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > 2000) throw ArgumentError('Message is too long.');
    UgcTextPolicy.ensureAllowed(trimmed);

    final batch = _firestore.batch();
    final messageRef = _firestore.collection('messages').doc();
    final conversationRef =
        _firestore.collection('conversations').doc(conversationId);
    batch.set(messageRef, {
      'conversationId': conversationId,
      'senderUid': senderUid,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'messageType': 'text',
      'readBy': [senderUid],
    });
    // Firestore rules bind these two fields to the exact message created in this
    // same atomic batch. A modified client cannot fake conversation activity by
    // bumping lastMessageAt without also creating an authorized message.
    batch.update(conversationRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageId': messageRef.id,
    });
    await batch.commit();
  }

  Future<void> markRead(String messageId) async {
    final uid = _requireUid();
    await _firestore.collection('messages').doc(messageId).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }
}
