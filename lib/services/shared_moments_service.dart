import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SharedMoment {
  const SharedMoment({
    required this.momentId,
    required this.creatorUid,
    required this.kind,
    required this.title,
    required this.note,
    required this.placeLabel,
    required this.sourceMessageId,
    required this.sourceMessagePreview,
    required this.sourceMessageFromCaller,
    required this.createdAtMs,
  });

  final String momentId;
  final String creatorUid;
  final String kind;
  final String title;
  final String note;
  final String placeLabel;
  final String sourceMessageId;
  final String sourceMessagePreview;
  final bool sourceMessageFromCaller;
  final int? createdAtMs;

  factory SharedMoment.fromMap(Map<String, dynamic> data) {
    return SharedMoment(
      momentId: data['momentId']?.toString() ?? '',
      creatorUid: data['creatorUid']?.toString() ?? '',
      kind: data['kind']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      note: data['note']?.toString() ?? '',
      placeLabel: data['placeLabel']?.toString() ?? '',
      sourceMessageId: data['sourceMessageId']?.toString() ?? '',
      sourceMessagePreview: data['sourceMessagePreview']?.toString() ?? '',
      sourceMessageFromCaller: data['sourceMessageFromCaller'] == true,
      createdAtMs: switch (data['createdAtMs']) {
        final num value => value.toInt(),
        _ => null,
      },
    );
  }
}

class SharedMomentsService {
  SharedMomentsService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  void _requireSignedIn() {
    if (_auth.currentUser == null) throw StateError('No signed-in user.');
  }

  String _requiredText(String value, String label, int maxLength) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > maxLength) {
      throw ArgumentError('Invalid $label.');
    }
    return normalized;
  }

  String _optionalText(String value, String label, int maxLength) {
    final normalized = value.trim();
    if (normalized.length > maxLength) throw ArgumentError('Invalid $label.');
    return normalized;
  }

  Future<String> createNote({
    required String conversationId,
    required String title,
    String note = '',
  }) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('createSharedMoment');
    final result = await callable.call<Map<String, dynamic>>({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
      'kind': 'note',
      'title': _requiredText(title, 'title', 120),
      'note': _optionalText(note, 'note', 1200),
    });
    return result.data['momentId']?.toString() ?? '';
  }

  Future<String> createPlace({
    required String conversationId,
    required String title,
    required String placeLabel,
    String note = '',
  }) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('createSharedMoment');
    final result = await callable.call<Map<String, dynamic>>({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
      'kind': 'place',
      'title': _requiredText(title, 'title', 120),
      'placeLabel': _requiredText(placeLabel, 'place label', 160),
      'note': _optionalText(note, 'note', 1200),
    });
    return result.data['momentId']?.toString() ?? '';
  }

  Future<String> saveMessage({
    required String conversationId,
    required String sourceMessageId,
    String note = '',
  }) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('createSharedMoment');
    final result = await callable.call<Map<String, dynamic>>({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
      'kind': 'message',
      'sourceMessageId': _requiredText(sourceMessageId, 'message', 128),
      'note': _optionalText(note, 'note', 1200),
    });
    return result.data['momentId']?.toString() ?? '';
  }

  Future<List<SharedMoment>> list({required String conversationId}) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('listSharedMoments');
    final result = await callable.call<Map<String, dynamic>>({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
    });
    final raw = result.data['moments'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => SharedMoment.fromMap(Map<String, dynamic>.from(item)))
        .where((moment) => moment.momentId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> delete({
    required String conversationId,
    required String momentId,
  }) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('deleteSharedMoment');
    await callable.call({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
      'momentId': _requiredText(momentId, 'moment', 128),
    });
  }
}
