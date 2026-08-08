import 'package:cloud_firestore/cloud_firestore.dart';

class MessagingService {
  MessagingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String canonicalConversationId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<String> ensureConversation(String currentUid, String otherUid) async {
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

  Stream<QuerySnapshot<Map<String, dynamic>>> watchConversations(String uid) {
    return _firestore
        .collection('conversations')
        .where('participantUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('createdAt')
        .limitToLast(100)
        .snapshots();
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderUid,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
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

  Future<void> markRead(String messageId, String uid) async {
    await _firestore.collection('messages').doc(messageId).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }
}
