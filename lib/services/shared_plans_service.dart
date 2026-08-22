import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SharedPlan {
  const SharedPlan({
    required this.planId,
    required this.creatorUid,
    required this.title,
    required this.note,
    required this.placeLabel,
    required this.plannedForMs,
    required this.status,
  });

  final String planId;
  final String creatorUid;
  final String title;
  final String note;
  final String placeLabel;
  final int? plannedForMs;
  final String status;

  factory SharedPlan.fromMap(Map<String, dynamic> data) {
    return SharedPlan(
      planId: data['planId']?.toString() ?? '',
      creatorUid: data['creatorUid']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      note: data['note']?.toString() ?? '',
      placeLabel: data['placeLabel']?.toString() ?? '',
      plannedForMs: switch (data['plannedForMs']) {
        final num value => value.toInt(),
        _ => null,
      },
      status: data['status']?.toString() ?? '',
    );
  }
}

class SharedPlansService {
  SharedPlansService({
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

  Map<String, dynamic> _planPayload({
    required String conversationId,
    required String title,
    required DateTime plannedFor,
    required String placeLabel,
    required String note,
  }) {
    return {
      'conversationId': _requiredText(conversationId, 'conversation', 128),
      'title': _requiredText(title, 'title', 120),
      'plannedForMs': plannedFor.millisecondsSinceEpoch,
      'placeLabel': _optionalText(placeLabel, 'place label', 160),
      'note': _optionalText(note, 'note', 1200),
    };
  }

  Future<String> create({
    required String conversationId,
    required String title,
    required DateTime plannedFor,
    String placeLabel = '',
    String note = '',
  }) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('createSharedPlan');
    final result = await callable.call<Map<String, dynamic>>(
      _planPayload(
        conversationId: conversationId,
        title: title,
        plannedFor: plannedFor,
        placeLabel: placeLabel,
        note: note,
      ),
    );
    return result.data['planId']?.toString() ?? '';
  }

  Future<List<SharedPlan>> list({required String conversationId}) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('listSharedPlans');
    final result = await callable.call<Map<String, dynamic>>({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
    });
    final raw = result.data['plans'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => SharedPlan.fromMap(Map<String, dynamic>.from(item)))
        .where((plan) => plan.planId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> update({
    required String conversationId,
    required String planId,
    required String title,
    required DateTime plannedFor,
    String placeLabel = '',
    String note = '',
  }) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('updateSharedPlan');
    await callable.call({
      ..._planPayload(
        conversationId: conversationId,
        title: title,
        plannedFor: plannedFor,
        placeLabel: placeLabel,
        note: note,
      ),
      'planId': _requiredText(planId, 'plan', 128),
    });
  }

  Future<void> cancel({
    required String conversationId,
    required String planId,
  }) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('cancelSharedPlan');
    await callable.call({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
      'planId': _requiredText(planId, 'plan', 128),
    });
  }
}
