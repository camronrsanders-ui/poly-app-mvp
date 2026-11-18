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

Future<void> _pumpCard(
  WidgetTester tester,
  CheckInActions actions, {
  Listenable? refreshListenable,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CheckInCard(
            actions: actions,
            otherDisplayName: 'Alex',
            otherUid: 'member-2',
            refreshListenable: refreshListenable,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The card starts collapsed (H-5); tests that exercise the full card
/// expand it first, exactly as a member would.
Future<void> _expandCard(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('check-in-toggle')));
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
    await _expandCard(tester);

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
    await _expandCard(tester);

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
    await _expandCard(tester);

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
    await _expandCard(tester);

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
    await _expandCard(tester);

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
    await _expandCard(tester);

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
    await _expandCard(tester);
    expect(find.byKey(const Key('check-in-my-state')), findsOneWidget);
  });

  testWidgets('card starts collapsed with a one-line summary',
      (tester) async {
    await _pumpCard(
      tester,
      _actions(
        snapshot: CheckInSnapshot(
          otherUid: 'member-2',
          myState: _currentSlot('doing_well', note: 'Good morning.'),
          otherState: _currentSlot('tender'),
          sharedNote: SharedCheckInNote(
            text: 'Dinner Friday.',
            updatedByUid: 'member-2',
            updatedAtMs: _nowMs() - 60_000,
          ),
        ),
      ),
    );

    // The full card — header, slot rows, note section — is not rendered.
    expect(find.text('How are we doing right now?'), findsNothing);
    expect(find.byKey(const Key('check-in-my-state')), findsNothing);
    expect(find.byKey(const Key('check-in-shared-note')), findsNothing);

    // The summary still carries the information: both current labels,
    // the shared-note indicator, and the as-of cue.
    expect(
      find.text('You: Doing well · Alex: Tender / having a hard day'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    expect(find.text('Updated just now'), findsOneWidget);
  });

  testWidgets('collapsed summary shows an expired state as unset',
      (tester) async {
    await _pumpCard(
      tester,
      _actions(
        snapshot: CheckInSnapshot(
          otherUid: 'member-2',
          myState: _currentSlot('okay'),
          otherState: _expiredSlot('need_space'),
          sharedNote: null,
        ),
      ),
    );

    expect(find.text('You: Okay · Alex: —'), findsOneWidget);
    expect(find.textContaining('Need space'), findsNothing);
  });

  testWidgets('collapsed card with nothing current invites a check-in',
      (tester) async {
    await _pumpCard(
      tester,
      _actions(
        snapshot: const CheckInSnapshot(
          otherUid: 'member-2',
          myState: null,
          otherState: null,
          sharedNote: null,
        ),
      ),
    );

    expect(find.text('Check in — how are we doing?'), findsOneWidget);
  });

  testWidgets('expansion is session-only and collapses back',
      (tester) async {
    CheckInActions buildActions() => _actions(
          snapshot: CheckInSnapshot(
            otherUid: 'member-2',
            myState: _currentSlot('doing_well'),
            otherState: null,
            sharedNote: null,
          ),
        );

    await _pumpCard(tester, buildActions());
    await _expandCard(tester);
    expect(find.byKey(const Key('check-in-my-state')), findsOneWidget);
    // The as-of cue renders under the header when expanded too.
    expect(find.text('Updated just now'), findsOneWidget);

    // Collapsing returns to the summary.
    await tester.tap(find.byKey(const Key('check-in-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('check-in-my-state')), findsNothing);
    expect(find.byKey(const Key('check-in-summary')), findsOneWidget);

    // A fresh card (a new chat-open) starts collapsed again: expansion
    // is never remembered.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await _pumpCard(tester, buildActions());
    expect(find.byKey(const Key('check-in-my-state')), findsNothing);
    expect(find.byKey(const Key('check-in-summary')), findsOneWidget);
  });

  testWidgets('bumping the refresh listenable reloads the card',
      (tester) async {
    var loads = 0;
    final notifier = ValueNotifier<int>(0);
    addTearDown(notifier.dispose);
    final actions = CheckInActions(
      load: () async {
        loads++;
        return CheckInSnapshot(
          otherUid: 'member-2',
          myState: null,
          otherState: _currentSlot(loads == 1 ? 'okay' : 'need_space'),
          sharedNote: null,
        );
      },
      setMyState: ({required state, note = ''}) async {},
      clearMyState: () async {},
      setSharedNote: (_) async {},
      clearSharedNote: () async {},
    );

    await _pumpCard(tester, actions, refreshListenable: notifier);
    expect(loads, 1);
    expect(find.text('You: — · Alex: Okay'), findsOneWidget);

    notifier.value++;
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(find.text('You: — · Alex: Need space'), findsOneWidget);

    // The 30-second relative-time ticker fires without extra loads and
    // the as-of cue survives it.
    await tester.pump(const Duration(seconds: 31));
    expect(loads, 2);
    expect(find.byKey(const Key('check-in-updated')), findsOneWidget);
  });

  testWidgets('clearing the shared note asks for confirmation first',
      (tester) async {
    var clears = 0;
    await _pumpCard(
      tester,
      _actions(
        snapshot: CheckInSnapshot(
          otherUid: 'member-2',
          myState: null,
          otherState: null,
          sharedNote: SharedCheckInNote(
            text: 'Dinner at 7 on Friday.',
            updatedByUid: 'member-2',
            updatedAtMs: _nowMs() - 60_000,
          ),
        ),
        onClearNote: () => clears++,
      ),
    );
    await _expandCard(tester);

    await tester.tap(find.byKey(const Key('check-in-clear-note')));
    await tester.pumpAndSettle();
    expect(find.text('Clear the shared note?'), findsOneWidget);
    expect(clears, 0);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Clear the shared note?'), findsNothing);
    expect(clears, 0);

    await tester.tap(find.byKey(const Key('check-in-clear-note')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('check-in-clear-note-confirm')));
    await tester.pumpAndSettle();
    expect(clears, 1);
  });

  testWidgets('state dialog says your partner will see this note',
      (tester) async {
    await _pumpCard(
      tester,
      _actions(
        snapshot: const CheckInSnapshot(
          otherUid: 'member-2',
          myState: null,
          otherState: null,
          sharedNote: null,
        ),
      ),
    );
    await _expandCard(tester);

    await tester.tap(find.byKey(const Key('check-in-set-state')));
    await tester.pumpAndSettle();
    expect(find.text('Your partner will see this note'), findsOneWidget);
  });
}
