import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One selectable check-in state. The ids and labels mirror the backend
/// vocabulary in functions/src/connection_check_in_fields.ts; the two
/// lists must change together.
class CheckInStateOption {
  const CheckInStateOption({required this.id, required this.label});

  final String id;
  final String label;
}

const List<CheckInStateOption> checkInStateOptions = [
  CheckInStateOption(id: 'doing_well', label: 'Doing well'),
  CheckInStateOption(id: 'okay', label: 'Okay'),
  CheckInStateOption(id: 'tender', label: 'Tender / having a hard day'),
  CheckInStateOption(id: 'need_space', label: 'Need space'),
  CheckInStateOption(id: 'want_to_talk', label: 'Want to talk'),
  CheckInStateOption(id: 'celebrating', label: 'Celebrating something'),
];

String checkInStateLabel(String stateId) {
  for (final option in checkInStateOptions) {
    if (option.id == stateId) return option.label;
  }
  return stateId;
}

/// A participant's current state slot, exactly as the backend projects
/// it. Expiry is a property of the slot: [isCurrentAt] is the check the
/// UI uses so a stale state is never rendered as current.
class CheckInSlot {
  const CheckInSlot({
    required this.state,
    required this.note,
    required this.updatedAtMs,
    required this.expiresAtMs,
  });

  final String state;
  final String note;
  final int updatedAtMs;
  final int expiresAtMs;

  bool isCurrentAt(int nowMs) => expiresAtMs > nowMs;

  factory CheckInSlot.fromMap(Map<String, dynamic> data) {
    return CheckInSlot(
      state: data['state']?.toString() ?? '',
      note: data['note']?.toString() ?? '',
      updatedAtMs: switch (data['updatedAtMs']) {
        final num value => value.toInt(),
        _ => 0,
      },
      expiresAtMs: switch (data['expiresAtMs']) {
        final num value => value.toInt(),
        _ => 0,
      },
    );
  }
}

/// The jointly editable note. Attribution ([updatedByUid] + [updatedAtMs])
/// is part of the value and is always shown in the UI.
class SharedCheckInNote {
  const SharedCheckInNote({
    required this.text,
    required this.updatedByUid,
    required this.updatedAtMs,
  });

  final String text;
  final String updatedByUid;
  final int updatedAtMs;

  factory SharedCheckInNote.fromMap(Map<String, dynamic> data) {
    return SharedCheckInNote(
      text: data['text']?.toString() ?? '',
      updatedByUid: data['updatedByUid']?.toString() ?? '',
      updatedAtMs: switch (data['updatedAtMs']) {
        final num value => value.toInt(),
        _ => 0,
      },
    );
  }
}

/// A caller-relative view of a conversation's check-in: my slot, the
/// other participant's slot, and the shared note. Slots may be present
/// but expired; use [currentMine]/[currentOther] for rendering.
class CheckInSnapshot {
  const CheckInSnapshot({
    required this.otherUid,
    required this.myState,
    required this.otherState,
    required this.sharedNote,
  });

  final String otherUid;
  final CheckInSlot? myState;
  final CheckInSlot? otherState;
  final SharedCheckInNote? sharedNote;

  CheckInSlot? currentMine(int nowMs) {
    final slot = myState;
    return slot != null && slot.isCurrentAt(nowMs) ? slot : null;
  }

  CheckInSlot? currentOther(int nowMs) {
    final slot = otherState;
    return slot != null && slot.isCurrentAt(nowMs) ? slot : null;
  }

  factory CheckInSnapshot.fromMap(Map<String, dynamic> data) {
    CheckInSlot? slot(dynamic raw) {
      if (raw is! Map) return null;
      return CheckInSlot.fromMap(Map<String, dynamic>.from(raw));
    }

    final rawNote = data['sharedNote'];
    return CheckInSnapshot(
      otherUid: data['otherUid']?.toString() ?? '',
      myState: slot(data['myState']),
      otherState: slot(data['otherState']),
      sharedNote: rawNote is Map
          ? SharedCheckInNote.fromMap(Map<String, dynamic>.from(rawNote))
          : null,
    );
  }
}

typedef CheckInLoader = Future<CheckInSnapshot> Function();
typedef CheckInStateSetter = Future<void> Function({
  required String state,
  String note,
});
typedef CheckInAction = Future<void> Function();
typedef CheckInNoteSetter = Future<void> Function(String text);

/// The operations the check-in card needs, bundled so the card stays
/// independent of Firebase and widget tests can substitute fakes.
/// Production code builds these from [CheckInService.fromService].
class CheckInActions {
  const CheckInActions({
    required this.load,
    required this.setMyState,
    required this.clearMyState,
    required this.setSharedNote,
    required this.clearSharedNote,
  });

  final CheckInLoader load;
  final CheckInStateSetter setMyState;
  final CheckInAction clearMyState;
  final CheckInNoteSetter setSharedNote;
  final CheckInAction clearSharedNote;

  factory CheckInActions.fromService(
    CheckInService service,
    String conversationId,
  ) {
    return CheckInActions(
      load: () => service.get(conversationId: conversationId),
      setMyState: ({required state, note = ''}) => service.setMyState(
        conversationId: conversationId,
        state: state,
        note: note,
      ),
      clearMyState: () => service.clearMyState(conversationId: conversationId),
      setSharedNote: (text) => service.setSharedNote(
        conversationId: conversationId,
        text: text,
      ),
      clearSharedNote: () =>
          service.clearSharedNote(conversationId: conversationId),
    );
  }
}

class CheckInService {
  CheckInService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _injectedAuth = auth,
        _injectedFunctions = functions;

  static const int noteMaxLength = 280;

  // Firebase singletons resolve lazily, on first actual use, so merely
  // constructing the service (e.g. while a screen builds) never touches
  // Firebase.
  final FirebaseAuth? _injectedAuth;
  final FirebaseFunctions? _injectedFunctions;
  FirebaseAuth? _authInstance;
  FirebaseFunctions? _functionsInstance;

  FirebaseAuth get _auth =>
      _authInstance ??= _injectedAuth ?? FirebaseAuth.instance;
  FirebaseFunctions get _functions =>
      _functionsInstance ??= _injectedFunctions ?? FirebaseFunctions.instance;

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

  Future<CheckInSnapshot> get({required String conversationId}) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('getCheckIn');
    final result = await callable.call<Map<String, dynamic>>({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
    });
    return CheckInSnapshot.fromMap(result.data);
  }

  Future<void> setMyState({
    required String conversationId,
    required String state,
    String note = '',
  }) async {
    _requireSignedIn();
    if (!checkInStateOptions.any((option) => option.id == state)) {
      throw ArgumentError('Invalid check-in state.');
    }
    final callable = _functions.httpsCallable('setMyCheckInState');
    await callable.call({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
      'state': state,
      'note': _optionalText(note, 'check-in note', noteMaxLength),
    });
  }

  Future<void> clearMyState({required String conversationId}) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('clearMyCheckInState');
    await callable.call({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
    });
  }

  Future<void> setSharedNote({
    required String conversationId,
    required String text,
  }) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('setSharedCheckInNote');
    await callable.call({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
      'text': _requiredText(text, 'shared note', noteMaxLength),
    });
  }

  Future<void> clearSharedNote({required String conversationId}) async {
    _requireSignedIn();
    final callable = _functions.httpsCallable('clearSharedCheckInNote');
    await callable.call({
      'conversationId': _requiredText(conversationId, 'conversation', 128),
    });
  }
}
