import 'package:cloud_firestore/cloud_firestore.dart';

import 'ugc_text_policy.dart';

class RelationshipCardService {
  RelationshipCardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _cards =>
      _firestore.collection('relationship_cards');

  Stream<List<Map<String, dynamic>>> watchCards(String ownerUid) {
    return _cards
        .where('ownerUid', isEqualTo: ownerUid)
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> createCard({
    required String ownerUid,
    required String label,
    required String connectionType,
    required String status,
    required String note,
    required String visibility,
    String displayNameOptional = '',
    required int sortOrder,
  }) async {
    UgcTextPolicy.ensureAllowedValues([label, displayNameOptional, note]);
    await _cards.add({
      'ownerUid': ownerUid,
      'label': label.trim(),
      'connectionType': connectionType,
      'displayNameOptional': displayNameOptional.trim(),
      'status': status,
      'note': note.trim(),
      'visibility': visibility,
      'sortOrder': sortOrder,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCard({
    required String cardId,
    required String ownerUid,
    required Map<String, dynamic> values,
  }) async {
    UgcTextPolicy.ensureAllowedValues([
      values['label']?.toString() ?? '',
      values['displayNameOptional']?.toString() ?? '',
      values['note']?.toString() ?? '',
    ]);
    await _cards.doc(cardId).update({
      ...values,
      'ownerUid': ownerUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deactivateCard(String cardId) async {
    await _cards.doc(cardId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCard(String cardId) => _cards.doc(cardId).delete();

  Future<void> reorderCards(List<Map<String, dynamic>> cards) async {
    final batch = _firestore.batch();
    for (var i = 0; i < cards.length; i++) {
      final id = cards[i]['id'] as String;
      batch.update(_cards.doc(id), {
        'sortOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
