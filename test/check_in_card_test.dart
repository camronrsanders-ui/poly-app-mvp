import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/services/check_in_service.dart';
import 'package:polycircle/widgets/check_in_card.dart';

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

CheckInSlot _slot({
  required String state,
  String note = '',
  required int ageMs,
  required int ttlMs,
}) {
  final updated = _nowMs() - ageMs;
  return CheckInSlot(
    state: state,
    note: note,
    updatedAtMs: updated,
    expiresAtMs: updated + ttlMs,
  );
}

CheckInSlot _currentSlot(String state, {String note = ''}) => _slot(
      state: state,
      note: note,
      ageMs: 5 * 60_000,
      ttlMs: 24 * 60 * 60_000,
    );

CheckInSlot _expiredSlot(String state) => _slot(
      state: state,
      ageMs: 25 * 60 * 60_000,
      ttlMs: 24 * 60 * 60_000,
    );

CheckInActions _actions({
  required CheckInSnapshot snapshot,
  void Function(String state, String note)? onSetState,
  void Function(String text)? onSetNote,
  VoidCallback? onClearState,
  VoidCallback? onClearNote,
}) {
  return CheckInActions(
    load: () async => snapshot,
    setMyState: ({required state, note = ''}) async {
      onSetState?.call(state, note);
    },
    clearMyState: () async {
      onClearState?.call();
    },
    setSharedNote: (text) async {
      onSetNote?.call(text);
    },
    clearSharedNote: () async {
      onClearNote?.call();
    },
  );
}

Future<void> _pumpCard(WidgetTester tester, CheckInActions actions) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CheckInCard(
            actions: actions,
            otherDisplayName: 'Alex',
            otherUid: 'member-2',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('both participants current states render', (tester) async {
    await _pumpCard(
      tester,
      _actions(
        snapshot: CheckInSnapshot(
          otherUid: 'member-2',
          myState: _currentSlot('doing_well', note: 'Good morning.'),
          otherState: _currentSlot('tender'),
          sharedNote: null,
        ),
      ),
    );

    expect(find.byKey(const Key('check-in-card')), findsOneWidget);
    expect(find.text('How are we doing right now?'), findsOneWidget);

    final mine = find.byKey(const Key('check-in-my-state'));
    expect(
        find.descendant(of: mine, matching: find.text('You')), findsOneWidget);
    expect(
      find.descendant(of: mine, matching: find.text('Doing well')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mine, matching: find.text('Good morning.')),
      findsOneWidget,
    );

    final other = find.byKey(const Key('check-in-other-state'));
    expect(
      find.descendant(of: other, matching: find.text('Alex')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: other,
        matching: find.text('Tender / having a hard day'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an expired state renders as unset, not as a stale state',
      (tester) async {
    await _pumpCard(
      tester,
      _actions(
        snapshot: CheckInSnapshot(
          otherUid: 'member-2',
          myState: _expiredSlot('need_space'),
          otherState: _currentSlot('okay'),
          sharedNote: null,
        ),
      ),
    );

    final mine = find.byKey(const Key('check-in-my-state'));
    expect(
      find.descendant(of: mine, matching: find.text('No current check-in')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mine, matching: find.text('Need space')),
      findsNothing,
    );
    // A fresh post is invited instead of showing the stale state.
    expect(
      find.descendant(of: mine, matching: find.text('Check in')),
      findsOneWidget,
    );

    final other = find.byKey(const Key('check-in-other-state'));
    expect(
      find.descendant(of: other, matching: find.text('Okay')),
      findsOneWidget,
    );
  });

  testWidgets('shared note shows who last edited it', (tester) async {
    final now = _nowMs();
    await _pumpCard(
      tester,
      _actions(
        snapshot: CheckInSnapshot(
          otherUid: 'member-2',
          myState: null,
          otherState: null,
          sharedNote: SharedCheckInNote(
            text: 'Running late Friday, still on for dinner.',
            updatedByUid: 'member-2',
            updatedAtMs: now - 2 * 60 * 60_000,
          ),
        ),
      ),
    );

    final note = find.byKey(const Key('check-in-shared-note'));
    expect(
      find.descendant(
        of: note,
        matching: find.text('Running late Friday, still on for dinner.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: note,
        matching: find.text('Last edited by Alex · 2h ago'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shared note edited by me is attributed to you', (tester) async {
    final now = _nowMs();
    await _pumpCard(
      tester,
      _actions(
        snapshot: CheckInSnapshot(
          otherUid: 'member-2',
          myState: null,
          otherState: null,
          sharedNote: SharedCheckInNote(
            text: 'I booked the table.',
            updatedByUid: 'member-1',
            updatedAtMs: now - 10 * 60_000,
          ),
        ),
      ),
    );

    expect(find.text('Last edited by you · 10m ago'), findsOneWidget);
  });

  testWidgets('posting a check-in sends the chosen state to the backend',
      (tester) async {
    String? postedState;
    String? postedNote;
    await _pumpCard(
      tester,
      _actions(
        snapshot: const CheckInSnapshot(
          otherUid: 'member-2',
          myState: null,
          otherState: null,
          sharedNote: null,
        ),
        onSetState: (state, note) {
          postedState = state;
          postedNote = note;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('check-in-set-state')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Want to talk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post check-in'));
    await tester.pumpAndSettle();

    expect(postedState, 'want_to_talk');
    expect(postedNote, '');
  });

  testWidgets('saving a shared note sends its text to the backend',
      (tester) async {
    String? savedNote;
    await _pumpCard(
      tester,
      _actions(
        snapshot: const CheckInSnapshot(
          otherUid: 'member-2',
          myState: null,
          otherState: null,
          sharedNote: null,
        ),
        onSetNote: (text) => savedNote = text,
      ),
    );

    await tester.tap(find.byKey(const Key('check-in-edit-note')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('check-in-shared-note-field')),
      'Dinner at 7 on Friday.',
    );
    await tester.tap(find.text('Save note'));
    await tester.pumpAndSettle();

    expect(savedNote, 'Dinner at 7 on Friday.');
  });

  testWidgets('a load failure offers a retry instead of fake content',
      (tester) async {
    var attempts = 0;
    final actions = CheckInActions(
      load: () async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
        return const CheckInSnapshot(
          otherUid: 'member-2',
          myState: null,
          otherState: null,
          sharedNote: null,
        );
      },
      setMyState: ({required state, note = ''}) async {},
      clearMyState: () async {},
      setSharedNote: (_) async {},
      clearSharedNote: () async {},
    );

    await _pumpCard(tester, actions);
    expect(find.text('Couldn’t load check-ins.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('check-in-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load check-ins.'), findsNothing);
    expect(find.byKey(const Key('check-in-my-state')), findsOneWidget);
  });
}
