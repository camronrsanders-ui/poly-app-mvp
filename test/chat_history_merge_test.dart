import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/messages/chat_screen.dart';

class _TestMessage {
  _TestMessage(this.id, this.createdAt);

  final String id;
  final Timestamp? createdAt;
}

void main() {
  test('retained and live messages merge chronologically', () {
    final retained = [
      _TestMessage('m1', Timestamp.fromDate(DateTime.utc(2026, 1, 1))),
      _TestMessage('m3', Timestamp.fromDate(DateTime.utc(2026, 1, 3))),
    ];
    final live = [
      _TestMessage('m2', Timestamp.fromDate(DateTime.utc(2026, 1, 2))),
      _TestMessage('m4', Timestamp.fromDate(DateTime.utc(2026, 1, 4))),
    ];

    final merged = mergeChatDocs<_TestMessage>(
      retained: retained,
      live: live,
      idOf: (message) => message.id,
      createdAtOf: (message) => message.createdAt,
    );

    expect(merged.map((message) => message.id).toList(), [
      'm1',
      'm2',
      'm3',
      'm4',
    ]);
  });

  test('live message wins on duplicate document ID', () {
    final retainedVersion =
        _TestMessage('m2', Timestamp.fromDate(DateTime.utc(2026, 1, 2)));
    final liveVersion =
        _TestMessage('m2', Timestamp.fromDate(DateTime.utc(2026, 1, 3)));

    final merged = mergeChatDocs<_TestMessage>(
      retained: [retainedVersion],
      live: [liveVersion],
      idOf: (message) => message.id,
      createdAtOf: (message) => message.createdAt,
    );

    expect(merged, hasLength(1));
    expect(merged.single, same(liveVersion));
  });

  test('equal timestamps use document ID ordering', () {
    final time = Timestamp.fromDate(DateTime.utc(2026, 1, 1));

    final merged = mergeChatDocs<_TestMessage>(
      retained: [
        _TestMessage('mB', time),
        _TestMessage('mA', time),
      ],
      live: const <_TestMessage>[],
      idOf: (message) => message.id,
      createdAtOf: (message) => message.createdAt,
    );

    expect(merged.map((message) => message.id).toList(), ['mA', 'mB']);
  });

  test('unresolved timestamps sort after resolved messages', () {
    final merged = mergeChatDocs<_TestMessage>(
      retained: [
        _TestMessage('pending', null),
        _TestMessage('resolved', Timestamp.fromDate(DateTime.utc(2026, 1, 1))),
      ],
      live: const <_TestMessage>[],
      idOf: (message) => message.id,
      createdAtOf: (message) => message.createdAt,
    );

    expect(merged.map((message) => message.id).toList(), [
      'resolved',
      'pending',
    ]);
  });

  test('merge does not mutate input collections', () {
    final retained = [
      _TestMessage('m2', Timestamp.fromDate(DateTime.utc(2026, 1, 2))),
      _TestMessage('m1', Timestamp.fromDate(DateTime.utc(2026, 1, 1))),
    ];
    final live = [
      _TestMessage('m3', Timestamp.fromDate(DateTime.utc(2026, 1, 3))),
    ];
    final retainedOrder = retained.map((message) => message.id).toList();
    final liveOrder = live.map((message) => message.id).toList();

    mergeChatDocs<_TestMessage>(
      retained: retained,
      live: live,
      idOf: (message) => message.id,
      createdAtOf: (message) => message.createdAt,
    );

    expect(retained.map((message) => message.id).toList(), retainedOrder);
    expect(live.map((message) => message.id).toList(), liveOrder);
  });

  test('moving live window returns only aged-out prefix documents', () {
    final previous = [
      _TestMessage('m1', null),
      _TestMessage('m2', null),
      _TestMessage('m3', null),
      _TestMessage('m4', null),
    ];
    final current = [
      _TestMessage('m3', null),
      _TestMessage('m4', null),
      _TestMessage('m5', null),
      _TestMessage('m6', null),
    ];

    final evicted = chatDocsEvictedFromLiveWindow<_TestMessage>(
      previousLive: previous,
      newLive: current,
      idOf: (message) => message.id,
      liveWindowSize: 4,
    );

    expect(evicted.map((message) => message.id).toList(), ['m1', 'm2']);
  });

  test('full live window jump retains the previous live window', () {
    final previous = List.generate(
      4,
      (index) => _TestMessage('m${index + 1}', null),
    );
    final current = List.generate(
      4,
      (index) => _TestMessage('m${index + 5}', null),
    );

    final evicted = chatDocsEvictedFromLiveWindow<_TestMessage>(
      previousLive: previous,
      newLive: current,
      idOf: (message) => message.id,
      liveWindowSize: 4,
    );

    expect(evicted.map((message) => message.id).toList(), [
      'm1',
      'm2',
      'm3',
      'm4',
    ]);
  });

  test(
    'partial previous window jump retains previous docs at full new window',
    () {
      final previous = [
        _TestMessage('m1', null),
        _TestMessage('m2', null),
      ];
      final current = [
        _TestMessage('m3', null),
        _TestMessage('m4', null),
        _TestMessage('m5', null),
        _TestMessage('m6', null),
      ];

      final evicted = chatDocsEvictedFromLiveWindow<_TestMessage>(
        previousLive: previous,
        newLive: current,
        idOf: (message) => message.id,
        liveWindowSize: 4,
      );

      expect(evicted.map((message) => message.id).toList(), ['m1', 'm2']);
    },
  );

  test('partial live window does not retain ambiguous removals', () {
    final evicted = chatDocsEvictedFromLiveWindow<_TestMessage>(
      previousLive: [
        _TestMessage('m1', null),
        _TestMessage('m2', null),
        _TestMessage('m3', null),
      ],
      newLive: [
        _TestMessage('m2', null),
        _TestMessage('m3', null),
      ],
      idOf: (message) => message.id,
      liveWindowSize: 3,
    );

    expect(evicted, isEmpty);
  });
}
