import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CircleSummary {
  const CircleSummary({
    required this.circleId,
    required this.name,
    required this.ownerUid,
    required this.role,
  });

  final String circleId;
  final String name;
  final String ownerUid;
  final String role;

  bool get isOwner => role == 'owner';

  factory CircleSummary.fromMap(
    Map<String, dynamic> data,
  ) {
    return CircleSummary(
      circleId: data['circleId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      ownerUid: data['ownerUid']?.toString() ?? '',
      role: data['role']?.toString() ?? 'member',
    );
  }
}

class CircleInviteSummary {
  const CircleInviteSummary({
    required this.inviteId,
    required this.circleId,
    required this.circleName,
    required this.inviterUid,
  });

  final String inviteId;
  final String circleId;
  final String circleName;
  final String inviterUid;

  factory CircleInviteSummary.fromMap(
    Map<String, dynamic> data,
  ) {
    return CircleInviteSummary(
      inviteId: data['inviteId']?.toString() ?? '',
      circleId: data['circleId']?.toString() ?? '',
      circleName: data['circleName']?.toString() ?? '',
      inviterUid: data['inviterUid']?.toString() ?? '',
    );
  }
}

class CircleMembershipSnapshot {
  const CircleMembershipSnapshot({
    required this.circles,
    required this.invites,
  });

  final List<CircleSummary> circles;
  final List<CircleInviteSummary> invites;
}

class CircleMembershipService {
  CircleMembershipService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  void _requireSignedIn() {
    if (_auth.currentUser == null) {
      throw StateError('No signed-in user.');
    }
  }

  Future<CircleSummary> createCircle(
    String name,
  ) async {
    _requireSignedIn();

    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('Circle name is required.');
    }

    final callable = _functions.httpsCallable('createCircle');

    final result = await callable.call<Map<String, dynamic>>({
      'name': cleanName,
    });

    final circleId = result.data['circleId']?.toString() ?? '';

    if (circleId.isEmpty) {
      throw StateError(
        'Circle creation did not return an ID.',
      );
    }

    return CircleSummary(
      circleId: circleId,
      name: result.data['name']?.toString() ?? cleanName,
      ownerUid: _auth.currentUser?.uid ?? '',
      role: result.data['role']?.toString() ?? 'owner',
    );
  }

  Future<CircleMembershipSnapshot> listMyCircles() async {
    _requireSignedIn();

    final callable = _functions.httpsCallable('listMyCircles');

    final result = await callable.call<Map<String, dynamic>>();

    final rawCircles = result.data['circles'];
    final rawInvites = result.data['invites'];

    final circles = rawCircles is List
        ? rawCircles
            .whereType<Map>()
            .map(
              (item) => CircleSummary.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .where(
              (circle) => circle.circleId.isNotEmpty,
            )
            .toList(growable: false)
        : const <CircleSummary>[];

    final invites = rawInvites is List
        ? rawInvites
            .whereType<Map>()
            .map(
              (item) => CircleInviteSummary.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .where(
              (invite) => invite.inviteId.isNotEmpty,
            )
            .toList(growable: false)
        : const <CircleInviteSummary>[];

    return CircleMembershipSnapshot(
      circles: circles,
      invites: invites,
    );
  }

  Future<String> inviteMember({
    required String circleId,
    required String inviteeUid,
  }) async {
    _requireSignedIn();

    final callable = _functions.httpsCallable(
      'inviteCircleMember',
    );

    final result = await callable.call<Map<String, dynamic>>({
      'circleId': circleId,
      'inviteeUid': inviteeUid,
    });

    if (result.data['invited'] != true) {
      throw StateError(
        'Circle invitation was not created.',
      );
    }

    return result.data['inviteId']?.toString() ?? '';
  }

  Future<bool> respondToInvite({
    required String inviteId,
    required bool accept,
  }) async {
    _requireSignedIn();

    final callable = _functions.httpsCallable(
      'respondToCircleInvite',
    );

    final result = await callable.call<Map<String, dynamic>>({
      'inviteId': inviteId,
      'accept': accept,
    });

    return result.data['accepted'] == true;
  }

  Future<void> leaveCircle(
    String circleId,
  ) async {
    _requireSignedIn();

    final callable = _functions.httpsCallable('leaveCircle');

    final result = await callable.call<Map<String, dynamic>>({
      'circleId': circleId,
    });

    if (result.data['left'] != true) {
      throw StateError(
        'Circle was not left.',
      );
    }
  }
}
