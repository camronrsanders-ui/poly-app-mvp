import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagingService {
  MessagingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user.');
    return uid;
  }

  String canonicalConversationId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<String> ensureConversation(String otherUid) async {
    final currentUid = _requireUid();
    if (currentUid == otherUid) throw ArgumentError('Cannot create a conversation with yourself.');
    final id = canonicalConversationId(currentUid, otherUid);
    final ref = _firestore.collection('conversations').doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participantUids': [currentUid, otherUid]..sort(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'active': true,
      });
    }
    return id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchConversations() {
    final uid = _requireUid();
    return _firestore
        .collection('conversations')
        .where('participantUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String conversationId) {
    _requireUid();
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('createdAt')
        .limitToLast(100)
        .snapshots();
  }

  Future<void> sendMessage({required String conversationId, required String text}) async {
    final senderUid = _requireUid();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > 2000) throw ArgumentError('Message is too long.');

    final batch = _firestore.batch();
    final messageRef = _firestore.collection('messages').doc();
    final conversationRef = _firestore.collection('conversations').doc(conversationId);
    batch.set(messageRef, {
      'conversationId': conversationId,
      'senderUid': senderUid,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'messageType': 'text',
      'readBy': [senderUid],
    });
    batch.set(conversationRef, {
      'lastMessageAt': FieldValue.serverTimestamp(),
      'active': true,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> markRead(String messageId) async {
    final uid = _requireUid();
    await _firestore.collection('messages').doc(messageId).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }
}
