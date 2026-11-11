import '../../widgets/polycircle_spatial_orbit.dart';

/// Draws only owner-to-person edges grounded in an actual mutual connection.
///
/// Joining a shared Circle does not prove two members are dating or otherwise
/// connected. A profile's self-described relationship status also does not
/// establish a relationship with the signed-in owner, nor does a card that
/// has not gone through an explicit person-link consent flow.
///
/// This builder is for the signed-in owner's private orbit only: do not reuse
/// its output as publicly visible relationship disclosures.
List<PolycircleTopologyLink> confirmedConnectionTopology({
  required String ownerUid,
  required Iterable<String> visibleUids,
  required Iterable<String> confirmedUids,
}) {
  final owner = ownerUid.trim();
  if (owner.isEmpty) return const <PolycircleTopologyLink>[];

  final confirmed = confirmedUids
      .map((value) => value.trim())
      .where((uid) => uid.isNotEmpty && uid != owner)
      .toSet();

  final seen = <String>{};
  final links = <PolycircleTopologyLink>[];
  for (final rawUid in visibleUids) {
    final uid = rawUid.trim();
    if (uid.isEmpty ||
        uid == owner ||
        uid == '__owner__' ||
        !confirmed.contains(uid) ||
        !seen.add(uid)) {
      continue;
    }
    links.add(
      PolycircleTopologyLink(
        fromId: '__owner__',
        toId: uid,
        label: 'Connected',
      ),
    );
  }
  return links;
}
