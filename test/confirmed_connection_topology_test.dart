import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/circle/confirmed_connection_topology.dart';

void main() {
  test('only accepted mutual connections become owner-anchored links', () {
    final links = confirmedConnectionTopology(
      ownerUid: 'owner',
      visibleUids: ['alex', 'riley', 'jordan'],
      confirmedUids: ['alex', 'jordan'],
    );
    expect(links.map((link) => link.toId), ['alex', 'jordan']);
    expect(links.every((link) => link.fromId == '__owner__'), isTrue);
    expect(links.every((link) => link.label == 'Connected'), isTrue);
  });

  test('shared Circle membership never implies a relationship edge', () {
    final links = confirmedConnectionTopology(
      ownerUid: 'owner',
      visibleUids: ['shared-only', 'other-member'],
      confirmedUids: ['accepted-person-not-in-this-world'],
    );
    expect(links, isEmpty);
  });

  test('duplicates, missing ids, self, and reserved owner are filtered', () {
    final links = confirmedConnectionTopology(
      ownerUid: ' owner ',
      visibleUids: ['', 'owner', '__owner__', 'alex', ' alex ', 'riley'],
      confirmedUids: ['owner', '__owner__', '', 'alex', 'riley', ' alex '],
    );
    expect(links.map((link) => link.toId), ['alex', 'riley']);
  });

  test('stale or revoked connections disappear on the next data reload', () {
    final before = confirmedConnectionTopology(
      ownerUid: 'owner',
      visibleUids: ['alex'],
      confirmedUids: ['alex'],
    );
    final after = confirmedConnectionTopology(
      ownerUid: 'owner',
      visibleUids: ['alex'],
      confirmedUids: [],
    );
    expect(before, hasLength(1));
    expect(after, isEmpty);
  });

  test('fails closed if the signed-in owner identity is absent', () {
    final links = confirmedConnectionTopology(
      ownerUid: ' ',
      visibleUids: ['alex'],
      confirmedUids: ['alex'],
    );
    expect(links, isEmpty);
  });
}
