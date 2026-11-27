import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/circle/my_circle_screen.dart';
import 'package:polycircle/services/circle_membership_service.dart';
import 'package:polycircle/services/profile_media_service.dart';
import 'package:polycircle/widgets/polycircle_spatial_orbit.dart';

Map<String, dynamic> connection(
  String uid,
  String name, {
  String city = 'Somerville',
}) =>
    <String, dynamic>{
      'uid': uid,
      'displayName': name,
      'age': 30,
      'city': city,
      'region': 'MA',
      'relationshipStructure': 'Polyamorous',
      'relationshipStatus': 'Connected',
      'headline': 'Community-minded',
    };

/// A connection whose self-described status is deliberately
/// distinct from the basis vocabulary, so text finders can never
/// confuse the basis line ("Connected to you") with the status
/// line ("… • Open to connections").
Map<String, dynamic> openConnection(
  String uid,
  String name,
) =>
    <String, dynamic>{
      'uid': uid,
      'displayName': name,
      'age': 30,
      'city': 'Somerville',
      'region': 'MA',
      'relationshipStructure': 'Polyamorous',
      'relationshipStatus': 'Open to connections',
      'headline': 'Community-minded',
    };

/// A Circle owned by someone else — a shared Circle — with member
/// records exactly as listMyCircles serves them: {uid,
/// displayName?} and nothing else.
CircleSummary sharedCircle({
  required String name,
  required List<Map<String, dynamic>> members,
  String circleId = 'circle-1',
}) {
  return CircleSummary(
    circleId: circleId,
    name: name,
    ownerUid: 'jordan',
    role: 'member',
    memberCount: members.length + 1,
    members: members,
  );
}

Future<void> openWorld(
  WidgetTester tester,
  String worldName,
) async {
  await tester.tap(find.text(worldName));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

CircleMembershipSnapshot snapshot({
  List<CircleSummary> circles = const <CircleSummary>[],
  List<CircleInviteSummary> invites = const <CircleInviteSummary>[],
  List<ArchivedCircleSummary> archivedCircles = const <ArchivedCircleSummary>[],
}) {
  return CircleMembershipSnapshot(
    circles: circles,
    invites: invites,
    archivedCircles: archivedCircles,
  );
}

Future<Map<String, dynamic>?> defaultProfile(String uid) async {
  return <String, dynamic>{
    'displayName': 'Cam',
  };
}

Future<CircleMembershipSnapshot> defaultSnapshot() async => snapshot();

Future<List<VisibleProfilePhoto>> defaultPhotos(String uid) async {
  return const <VisibleProfilePhoto>[];
}

bool isSpatialOrbit(Widget widget) {
  return widget is PolycircleSpatialOrbit<Map<String, dynamic>>;
}

Future<void> pumpCircle(
  WidgetTester tester, {
  required CircleConnectionsLoader loadConnections,
  MyCircleProfileLoader? loadProfile,
  MyCircleSnapshotLoader? loadSnapshot,
  MyCirclePhotosLoader? loadVisiblePhotos,
  MyCircleAction? openSafetyAction,
  MyCircleAction? openManagerAction,
  MyCircleProfileOpenAction? openProfileAction,
  MyCircleCreateAction? createCircleAction,
  MyCircleInviteAction? inviteMemberAction,
  MyCircleRespondAction? respondToInviteAction,
  MyCircleCircleAction? leaveCircleAction,
  MyCircleCircleAction? archiveCircleAction,
  MyCircleCircleAction? unarchiveCircleAction,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(1100, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: reduceMotion,
            accessibleNavigation: reduceMotion,
          ),
          child: child!,
        );
      },
      home: Scaffold(
        body: MyCircleScreen(
          uidProvider: () => 'owner-1',
          loadConnections: loadConnections,
          loadProfile: loadProfile ?? defaultProfile,
          loadSnapshot: loadSnapshot ?? defaultSnapshot,
          loadVisiblePhotos: loadVisiblePhotos ?? defaultPhotos,
          openSafetyAction: openSafetyAction,
          openManagerAction: openManagerAction,
          openProfileAction: openProfileAction,
          createCircleAction: createCircleAction,
          inviteMemberAction: inviteMemberAction,
          respondToInviteAction: respondToInviteAction,
          leaveCircleAction: leaveCircleAction,
          archiveCircleAction: archiveCircleAction,
          unarchiveCircleAction: unarchiveCircleAction,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Load failure exposes a working My Circle retry',
    (tester) async {
      var loads = 0;

      await pumpCircle(
        tester,
        loadConnections: () async {
          loads += 1;
          if (loads == 1) {
            throw StateError('temporary load failure');
          }
          return const <Map<String, dynamic>>[];
        },
      );

      expect(find.text('Reload My Circle'), findsOneWidget);

      await tester.tap(find.text('Reload My Circle'));
      await tester.pumpAndSettle();

      expect(loads, 2);
      expect(find.text('Your universe is waiting'), findsOneWidget);
    },
  );

  testWidgets(
    'Empty universe Safety and Manage actions are functional',
    (tester) async {
      var safetyCalls = 0;
      var manageCalls = 0;

      await pumpCircle(
        tester,
        loadConnections: () async => const <Map<String, dynamic>>[],
        openSafetyAction: () async {
          safetyCalls += 1;
        },
        openManagerAction: () async {
          manageCalls += 1;
        },
      );

      await tester.tap(find.byIcon(Icons.shield_outlined));
      await tester.pumpAndSettle();
      expect(safetyCalls, 1);

      await tester.tap(find.text('Manage relationships'));
      await tester.pumpAndSettle();
      expect(manageCalls, 1);
    },
  );

  testWidgets(
    'Populated universe keeps the spatial orbit and opens focused profile',
    (tester) async {
      Map<String, dynamic>? opened;

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[
          connection('alex', 'Alex'),
        ],
        openProfileAction: (person) async {
          opened = Map<String, dynamic>.from(person);
          return null;
        },
      );

      expect(find.text('MY CIRCLE'), findsOneWidget);
      expect(
        find.byWidgetPredicate(isSpatialOrbit),
        findsOneWidget,
      );
      expect(find.text('Alex, 30'), findsOneWidget);

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();

      expect(opened?['uid'], 'alex');
      expect(opened?['displayName'], 'Alex');
    },
  );

  testWidgets(
    'Blocking from profile triggers a fresh universe load',
    (tester) async {
      var loads = 0;

      await pumpCircle(
        tester,
        loadConnections: () async {
          loads += 1;
          return <Map<String, dynamic>>[
            connection('alex', 'Alex'),
          ];
        },
        openProfileAction: (person) async => 'blocked',
      );

      expect(loads, 1);

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();

      expect(loads, 2);
    },
  );

  testWidgets(
    'Circle world selection switches the active spatial universe',
    (tester) async {
      final alex = connection('alex', 'Alex');
      final circle = const CircleSummary(
        circleId: 'friends-1',
        name: 'Friends',
        ownerUid: 'owner-1',
        role: 'owner',
        memberCount: 1,
        members: <Map<String, dynamic>>[
          <String, dynamic>{
            'uid': 'alex',
            'displayName': 'Alex',
          },
        ],
      );

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[alex],
        loadSnapshot: () async => snapshot(
          circles: <CircleSummary>[circle],
        ),
      );

      expect(find.text('MY CIRCLE'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);

      await tester.tap(find.text('Friends'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.text('FRIENDS'), findsOneWidget);
      expect(find.text('Private Circle • You created this'), findsOneWidget);
      expect(find.text('Alex, 30'), findsOneWidget);
    },
  );

  testWidgets(
    'Create Circle enables only for a nonblank name and updates as text changes',
    (tester) async {
      var creates = 0;

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[
          connection('alex', 'Alex'),
        ],
        createCircleAction: (name) async {
          creates += 1;
          throw StateError('submit should remain disabled');
        },
      );

      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      final createButton = find.widgetWithText(FilledButton, 'Create Circle');
      final nameField = find.widgetWithText(TextField, 'Circle name');

      expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

      await tester.enterText(nameField, '   ');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

      await tester.enterText(nameField, ' Boston Crew ');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);

      await tester.enterText(nameField, ' ');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
      expect(creates, 0);
    },
  );

  testWidgets(
    'Create Circle sends the trimmed name and reports success',
    (tester) async {
      String? createdName;

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[
          connection('alex', 'Alex'),
        ],
        createCircleAction: (name) async {
          createdName = name;
          return const CircleSummary(
            circleId: 'new-circle',
            name: 'Boston Crew',
            ownerUid: 'owner-1',
            role: 'owner',
            memberCount: 1,
          );
        },
      );

      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      expect(find.text('Create a new world'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Circle name'),
        '  Boston Crew  ',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Circle'));
      await tester.pumpAndSettle();

      expect(createdName, 'Boston Crew');
      expect(
        find.text('Boston Crew is now part of your universe.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Failed Circle creation is recoverable on a later retry',
    (tester) async {
      var attempts = 0;

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[
          connection('alex', 'Alex'),
        ],
        createCircleAction: (name) async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('temporary create failure');
          }
          return const CircleSummary(
            circleId: 'retry-circle',
            name: 'Retry Circle',
            ownerUid: 'owner-1',
            role: 'owner',
            memberCount: 1,
          );
        },
      );

      for (var attempt = 0; attempt < 2; attempt += 1) {
        await tester.tap(find.text('New'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Circle name'),
          'Retry Circle',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create Circle'));
        await tester.pumpAndSettle();
      }

      expect(attempts, 2);
    },
  );

  testWidgets(
    'Owner invite sends the exact Circle and member IDs',
    (tester) async {
      String? invitedCircleId;
      String? invitedUid;
      final circle = const CircleSummary(
        circleId: 'friends-1',
        name: 'Friends',
        ownerUid: 'owner-1',
        role: 'owner',
        memberCount: 1,
      );

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[
          connection('alex', 'Alex'),
        ],
        loadSnapshot: () async => snapshot(
          circles: <CircleSummary>[circle],
        ),
        inviteMemberAction: ({
          required circleId,
          required inviteeUid,
        }) async {
          invitedCircleId = circleId;
          invitedUid = inviteeUid;
        },
      );

      await tester.tap(find.text('Friends'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Invite people'));
      await tester.pumpAndSettle();

      expect(find.text('Invite into Friends'), findsOneWidget);

      await tester.tap(find.text('Alex'));
      await tester.pumpAndSettle();

      expect(invitedCircleId, 'friends-1');
      expect(invitedUid, 'alex');
      expect(find.textContaining('Invitation sent to Alex'), findsOneWidget);
    },
  );

  testWidgets(
    'Incoming Circle invitation accepts with the exact decision',
    (tester) async {
      String? receivedInviteId;
      bool? acceptedDecision;
      final invite = const CircleInviteSummary(
        inviteId: 'invite-1',
        circleId: 'circle-1',
        circleName: 'Boston Crew',
        inviterUid: 'alex',
      );

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[
          connection('alex', 'Alex'),
        ],
        loadSnapshot: () async => snapshot(
          invites: <CircleInviteSummary>[invite],
        ),
        respondToInviteAction: ({
          required String inviteId,
          required bool accept,
        }) async {
          receivedInviteId = inviteId;
          acceptedDecision = accept;
          return accept;
        },
      );

      await tester.tap(find.text('1 Circle invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Circle invitations'), findsOneWidget);
      expect(find.text('Boston Crew'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(receivedInviteId, 'invite-1');
      expect(acceptedDecision, isTrue);
      expect(find.text('Welcome to Boston Crew.'), findsOneWidget);
    },
  );

  testWidgets(
    'Incoming Circle invitation can be explicitly declined',
    (tester) async {
      String? receivedInviteId;
      bool? acceptedDecision;
      final invite = const CircleInviteSummary(
        inviteId: 'invite-2',
        circleId: 'circle-2',
        circleName: 'Chosen Family',
        inviterUid: 'alex',
      );

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[
          connection('alex', 'Alex'),
        ],
        loadSnapshot: () async => snapshot(
          invites: <CircleInviteSummary>[invite],
        ),
        respondToInviteAction: ({
          required String inviteId,
          required bool accept,
        }) async {
          receivedInviteId = inviteId;
          acceptedDecision = accept;
          return false;
        },
      );

      await tester.tap(find.text('1 Circle invitation'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      expect(receivedInviteId, 'invite-2');
      expect(acceptedDecision, isFalse);
      expect(find.text('Circle invitation declined.'), findsOneWidget);
    },
  );

  testWidgets(
    'Previous and Next step focus through the roster',
    (tester) async {
      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[
          connection('ana', 'Ana'),
          connection('bo', 'Bo'),
          connection('cy', 'Cy'),
        ],
      );

      expect(find.text('Ana, 30'), findsOneWidget);

      await tester.tap(find.byTooltip('Next person'));
      await tester.pumpAndSettle();

      expect(find.text('Bo, 30'), findsOneWidget);

      await tester.tap(find.byTooltip('Next person'));
      await tester.pumpAndSettle();

      expect(find.text('Cy, 30'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous person'));
      await tester.pumpAndSettle();

      expect(find.text('Bo, 30'), findsOneWidget);
    },
  );

  testWidgets(
    'Everyone roster reaches people beyond the orbit render cap',
    (tester) async {
      await pumpCircle(
        tester,
        loadConnections: () async => List<Map<String, dynamic>>.generate(
          30,
          (index) => connection('person-$index', 'Person $index'),
        ),
      );

      // The total is always visible: the render cap is never silent.
      expect(find.text('Everyone · 30'), findsOneWidget);

      await tester.tap(find.text('Everyone · 30'));
      await tester.pumpAndSettle();

      expect(find.text('Everyone in My Circle'), findsOneWidget);
      expect(find.text('Person 1'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Person 29');
      await tester.pumpAndSettle();

      // Scoped to the roster tile: the search field's own text
      // also contains 'Person 29' at this point.
      final person29Tile = find.widgetWithText(
        ListTile,
        'Person 29',
      );

      expect(person29Tile, findsOneWidget);

      await tester.tap(person29Tile);
      await tester.pumpAndSettle();

      // Person 30 of 30 — outside the rendered window — is now
      // the focused person.
      expect(find.text('Person 29, 30'), findsOneWidget);
    },
  );

  testWidgets(
    'Reduced motion switches worlds instantly, without camera travel',
    (tester) async {
      final alex = connection('alex', 'Alex');
      final circle = const CircleSummary(
        circleId: 'friends-1',
        name: 'Friends',
        ownerUid: 'owner-1',
        role: 'owner',
        memberCount: 1,
        members: <Map<String, dynamic>>[
          <String, dynamic>{
            'uid': 'alex',
            'displayName': 'Alex',
          },
        ],
      );

      await pumpCircle(
        tester,
        reduceMotion: true,
        loadConnections: () async => <Map<String, dynamic>>[alex],
        loadSnapshot: () async => snapshot(
          circles: <CircleSummary>[circle],
        ),
      );

      expect(find.text('MY CIRCLE'), findsOneWidget);

      await tester.tap(find.text('Friends'));
      await tester.pump();

      // One frame, no 620ms camera travel: the world has swapped.
      expect(find.text('FRIENDS'), findsOneWidget);
      expect(find.text('Alex, 30'), findsOneWidget);
    },
  );

  testWidgets(
    'Populated owner Circle exposes Invite and Archive in Circle options',
    (tester) async {
      String? invitedCircleId;
      String? invitedUid;
      final alex = connection('alex', 'Alex');
      final circle = const CircleSummary(
        circleId: 'friends-1',
        name: 'Friends',
        ownerUid: 'owner-1',
        role: 'owner',
        memberCount: 2,
        members: <Map<String, dynamic>>[
          <String, dynamic>{
            'uid': 'alex',
            'displayName': 'Alex',
          },
        ],
      );

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[alex],
        loadSnapshot: () async => snapshot(
          circles: <CircleSummary>[circle],
        ),
        inviteMemberAction: ({
          required circleId,
          required inviteeUid,
        }) async {
          invitedCircleId = circleId;
          invitedUid = inviteeUid;
        },
      );

      await tester.tap(find.text('Friends'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Circle options'));
      await tester.pumpAndSettle();

      expect(find.text('Invite to this Circle'), findsOneWidget);
      expect(find.text('Archive this Circle'), findsOneWidget);
      expect(find.text('Leave this Circle'), findsNothing);

      await tester.tap(find.text('Invite to this Circle'));
      await tester.pumpAndSettle();

      expect(find.text('Invite into Friends'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Alex'));
      await tester.pumpAndSettle();

      expect(invitedCircleId, 'friends-1');
      expect(invitedUid, 'alex');
      expect(find.textContaining('Invitation sent to Alex'), findsOneWidget);
    },
  );

  testWidgets(
    'Member leaves a populated Circle only after confirming',
    (tester) async {
      final leftCircleIds = <String>[];
      final alex = connection('alex', 'Alex');
      final circle = const CircleSummary(
        circleId: 'book-club-1',
        name: 'Book Club',
        ownerUid: 'alex',
        role: 'member',
        memberCount: 2,
        members: <Map<String, dynamic>>[
          <String, dynamic>{
            'uid': 'alex',
            'displayName': 'Alex',
          },
        ],
      );

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[alex],
        loadSnapshot: () async => snapshot(
          circles: <CircleSummary>[circle],
        ),
        leaveCircleAction: (circleId) async {
          leftCircleIds.add(circleId);
        },
      );

      await tester.tap(find.text('Book Club'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Circle options'));
      await tester.pumpAndSettle();

      expect(find.text('Leave this Circle'), findsOneWidget);
      expect(find.text('Invite to this Circle'), findsNothing);
      expect(find.text('Archive this Circle'), findsNothing);

      await tester.tap(find.text('Leave this Circle'));
      await tester.pumpAndSettle();

      expect(find.text('Leave Book Club?'), findsOneWidget);
      expect(leftCircleIds, isEmpty);

      await tester.tap(find.text('Leave Circle'));
      await tester.pumpAndSettle();

      expect(leftCircleIds, <String>['book-club-1']);
      expect(find.text('You left Book Club.'), findsOneWidget);
    },
  );

  testWidgets(
    'Owner archives a populated Circle only after confirming',
    (tester) async {
      final archivedCircleIds = <String>[];
      final alex = connection('alex', 'Alex');
      final circle = const CircleSummary(
        circleId: 'friends-1',
        name: 'Friends',
        ownerUid: 'owner-1',
        role: 'owner',
        memberCount: 2,
        members: <Map<String, dynamic>>[
          <String, dynamic>{
            'uid': 'alex',
            'displayName': 'Alex',
          },
        ],
      );

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[alex],
        loadSnapshot: () async => snapshot(
          circles: <CircleSummary>[circle],
        ),
        archiveCircleAction: (circleId) async {
          archivedCircleIds.add(circleId);
        },
      );

      await tester.tap(find.text('Friends'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Circle options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Archive this Circle'));
      await tester.pumpAndSettle();

      expect(find.text('Archive Friends?'), findsOneWidget);
      expect(archivedCircleIds, isEmpty);

      await tester.tap(find.text('Archive Circle'));
      await tester.pumpAndSettle();

      expect(archivedCircleIds, <String>['friends-1']);
      expect(find.textContaining('is archived'), findsOneWidget);
    },
  );

  testWidgets(
    'Archived Circles restore from Circle options',
    (tester) async {
      final restoredCircleIds = <String>[];

      await pumpCircle(
        tester,
        loadConnections: () async => <Map<String, dynamic>>[
          connection('alex', 'Alex'),
        ],
        loadSnapshot: () async => snapshot(
          archivedCircles: const <ArchivedCircleSummary>[
            ArchivedCircleSummary(
              circleId: 'old-crew-1',
              name: 'Old Crew',
              memberCount: 3,
            ),
          ],
        ),
        unarchiveCircleAction: (circleId) async {
          restoredCircleIds.add(circleId);
        },
      );

      await tester.tap(find.byTooltip('Circle options'));
      await tester.pumpAndSettle();

      expect(find.text('Archived Circles'), findsOneWidget);

      await tester.tap(find.text('Archived Circles'));
      await tester.pumpAndSettle();

      expect(find.text('Old Crew'), findsOneWidget);

      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(restoredCircleIds, <String>['old-crew-1']);
    },
  );

  group('Cycle 2 — connection basis surfaces', () {
    // The Friends fixture: Jordan is the viewer's confirmed
    // connection AND a member of the shared Circle; Alex is a
    // member only. Ground truth the surfaces must state.
    Future<void> pumpFriends(
      WidgetTester tester, {
      bool reduceMotion = false,
      MyCircleProfileOpenAction? openProfileAction,
    }) async {
      await pumpCircle(
        tester,
        reduceMotion: reduceMotion,
        loadConnections: () async => <Map<String, dynamic>>[
          openConnection('jordan', 'Jordan'),
        ],
        loadSnapshot: () async => snapshot(
          circles: <CircleSummary>[
            sharedCircle(
              name: 'Friends',
              members: <Map<String, dynamic>>[
                <String, dynamic>{
                  'uid': 'jordan',
                  'displayName': 'Jordan',
                },
                <String, dynamic>{
                  'uid': 'alex',
                  'displayName': 'Alex',
                },
              ],
            ),
          ],
        ),
        openProfileAction: openProfileAction,
      );
    }

    testWidgets(
      'Circle glass states connection basis and attributes the style',
      (tester) async {
        await pumpFriends(tester);
        await openWorld(tester, 'Friends');

        // Jordan is focused by default (first in roster order).
        expect(find.text('Jordan, 30'), findsOneWidget);
        expect(find.text('Connected to you'), findsOneWidget);
        expect(
          find.text(
            'Their relationship style: Polyamorous • Open to connections',
          ),
          findsOneWidget,
        );

        // The bare join never appears as a standalone text.
        expect(
          find.text('Polyamorous • Open to connections'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Circle glass states co-member basis with the Circle named',
      (tester) async {
        await pumpFriends(tester);
        await openWorld(tester, 'Friends');

        await tester.tap(find.byTooltip('Next person'));
        await tester.pumpAndSettle();

        expect(
          find.text('In Friends with you · Not connected to you'),
          findsOneWidget,
        );
        expect(find.text('Connected to you'), findsNothing);
      },
    );

    testWidgets(
      'Mine world glass states connection basis',
      (tester) async {
        await pumpCircle(
          tester,
          loadConnections: () async => <Map<String, dynamic>>[
            openConnection('jordan', 'Jordan'),
          ],
        );

        expect(find.text('Jordan, 30'), findsOneWidget);
        expect(find.text('Connected to you'), findsOneWidget);
      },
    );

    testWidgets(
      'orbit node semantics announce basis for both kinds of people',
      (tester) async {
        await pumpFriends(tester);
        await openWorld(tester, 'Friends');

        // Alex is unfocused: his semantics label is exactly the
        // basis statement, with his name.
        expect(
          find.bySemanticsLabel(
            RegExp('Alex, in Friends with you, not connected to you'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Next person'));
        await tester.pumpAndSettle();

        // Now Jordan is unfocused and Alex focused; Jordan's label
        // states the connection basis.
        expect(
          find.bySemanticsLabel(RegExp('Jordan, connected to you')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'sparse connection still reads Connected to you (privacy C3)',
      (tester) async {
        // A confirmed connection whose profile carries nothing but
        // uid + displayName: the merged map is identical in
        // richness to a member record. Basis must come from the
        // topology set, never from field presence.
        await pumpCircle(
          tester,
          loadConnections: () async => <Map<String, dynamic>>[
            <String, dynamic>{
              'uid': 'jordan',
              'displayName': 'Jordan',
            },
          ],
          loadSnapshot: () async => snapshot(
            circles: <CircleSummary>[
              sharedCircle(
                name: 'Friends',
                members: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'uid': 'jordan',
                    'displayName': 'Jordan',
                  },
                  <String, dynamic>{
                    'uid': 'alex',
                    'displayName': 'Alex',
                  },
                ],
              ),
            ],
          ),
        );
        await openWorld(tester, 'Friends');

        expect(find.text('Connected to you'), findsOneWidget);
        expect(find.textContaining('Not connected to you'), findsNothing);

        await tester.tap(find.text('Everyone · 2'));
        await tester.pumpAndSettle();

        final jordanTile = find.widgetWithText(ListTile, 'Jordan');
        expect(jordanTile, findsOneWidget);
        final subtitle = tester.widget<ListTile>(jordanTile).subtitle;
        expect((subtitle as Text).data, 'Connected to you');
      },
    );

    testWidgets(
      'Everyone roster leads with basis and attributes the style',
      (tester) async {
        await pumpFriends(tester);
        await openWorld(tester, 'Friends');

        await tester.tap(find.text('Everyone · 2'));
        await tester.pumpAndSettle();

        // A member-only row previously had no subtitle at all; it
        // now carries exactly the basis segment.
        final alexTile = find.widgetWithText(ListTile, 'Alex');
        expect(alexTile, findsOneWidget);
        expect(
          (tester.widget<ListTile>(alexTile).subtitle as Text).data,
          'In Friends with you · Not connected to you',
        );

        final jordanTile = find.widgetWithText(ListTile, 'Jordan');
        expect(jordanTile, findsOneWidget);
        expect(
          (tester.widget<ListTile>(jordanTile).subtitle as Text).data,
          'Connected to you  •  '
          'Their relationship style: Polyamorous • Open to connections  •  '
          'Somerville, MA',
        );
      },
    );

    testWidgets(
      'nameless co-member is labelled Circle member, never Connection',
      (tester) async {
        await pumpCircle(
          tester,
          loadConnections: () async => <Map<String, dynamic>>[
            openConnection('jordan', 'Jordan'),
          ],
          loadSnapshot: () async => snapshot(
            circles: <CircleSummary>[
              sharedCircle(
                name: 'Friends',
                members: <Map<String, dynamic>>[
                  <String, dynamic>{'uid': 'alex'},
                ],
              ),
            ],
          ),
        );
        await openWorld(tester, 'Friends');

        expect(find.text('Circle member'), findsWidgets);
        expect(
          find.text('In Friends with you · Not connected to you'),
          findsOneWidget,
        );
        expect(find.text('Connection'), findsNothing);
      },
    );

    testWidgets(
      'nameless connection keeps the Connection fallback',
      (tester) async {
        await pumpCircle(
          tester,
          loadConnections: () async => <Map<String, dynamic>>[
            <String, dynamic>{'uid': 'jordan'},
          ],
        );

        expect(find.text('Connection'), findsWidgets);
        expect(find.text('Connected to you'), findsOneWidget);
        expect(find.text('Circle member'), findsNothing);
      },
    );

    testWidgets(
      'a long Circle name renders the full basis line, uncut',
      (tester) async {
        const longCircleName =
            'The Extraordinarily Long-Named Circle of Friends and Neighbors';

        await pumpCircle(
          tester,
          loadConnections: () async => <Map<String, dynamic>>[
            openConnection('jordan', 'Jordan'),
          ],
          loadSnapshot: () async => snapshot(
            circles: <CircleSummary>[
              sharedCircle(
                name: longCircleName,
                members: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'uid': 'alex',
                    'displayName': 'Alex',
                  },
                ],
              ),
            ],
          ),
        );
        await openWorld(tester, longCircleName);

        final basis = find.text(
          'In $longCircleName with you · Not connected to you',
        );
        expect(basis, findsOneWidget);

        // Never truncated: no line cap, no ellipsis.
        final basisText = tester.widget<Text>(basis);
        expect(basisText.maxLines, isNull);
        expect(basisText.overflow, isNull);
      },
    );

    testWidgets(
      'long names wrap in full in the roster and stay searchable',
      (tester) async {
        const longName = 'Alexandra Constantina Reyes-Hernandez '
            'De La Vega Montenegro Salazar Fernandez Jr';

        await pumpCircle(
          tester,
          loadConnections: () async => <Map<String, dynamic>>[
            openConnection('jordan', 'Jordan'),
          ],
          loadSnapshot: () async => snapshot(
            circles: <CircleSummary>[
              sharedCircle(
                name: 'Friends',
                members: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'uid': 'alex',
                    'displayName': longName,
                  },
                  <String, dynamic>{
                    'uid': 'jordan',
                    'displayName': 'Jordan',
                  },
                ],
              ),
            ],
          ),
        );
        await openWorld(tester, 'Friends');

        await tester.tap(find.text('Everyone · 2'));
        await tester.pumpAndSettle();

        final tile = find.widgetWithText(ListTile, longName);
        expect(tile, findsOneWidget);

        final title = tester.widget<ListTile>(tile).title as Text;
        expect(title.data, longName);
        expect(title.maxLines, isNull);

        await tester.enterText(find.byType(TextField), 'Constantina');
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ListTile, longName), findsOneWidget);
      },
    );

    testWidgets(
      'the person map that leaves the screen carries no basis (privacy C2)',
      (tester) async {
        final captured = <Map<String, dynamic>>[];

        await pumpCircle(
          tester,
          loadConnections: () async => <Map<String, dynamic>>[
            openConnection('jordan', 'Jordan'),
          ],
          loadSnapshot: () async => snapshot(
            circles: <CircleSummary>[
              sharedCircle(
                name: 'Friends',
                members: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'uid': 'alex',
                    'displayName': 'Alex',
                  },
                  <String, dynamic>{
                    'uid': 'jordan',
                    'displayName': 'Jordan',
                  },
                ],
              ),
            ],
          ),
          openProfileAction: (person) async {
            captured.add(Map<String, dynamic>.from(person));
            return null;
          },
        );
        await openWorld(tester, 'Friends');

        // Open both people's profiles, one step apart. (Which of
        // the two holds the initial focus is the orbit's business;
        // the containment claim is about both maps.)
        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Next person'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();

        expect(captured, hasLength(2));

        final bySize = [...captured]
          ..sort((a, b) => a.length.compareTo(b.length));

        // The member-only map is exactly the served member record…
        expect(
          bySize[0].keys,
          unorderedEquals(<String>['uid', 'displayName']),
        );

        // …and the connection map is exactly the connection
        // payload. Neither carries a basis key.
        expect(bySize[1].containsKey('basis'), isFalse);
        expect(
          bySize[1].keys,
          unorderedEquals(<String>[
            'uid',
            'displayName',
            'age',
            'city',
            'region',
            'relationshipStructure',
            'relationshipStatus',
            'headline',
          ]),
        );
        expect(bySize[0].containsKey('basis'), isFalse);
      },
    );

    testWidgets(
      'reduced motion keeps the basis statements',
      (tester) async {
        await pumpFriends(tester, reduceMotion: true);

        await tester.tap(find.text('Friends'));
        await tester.pump();

        // One frame, no camera travel — and the basis is stated.
        expect(find.text('FRIENDS'), findsOneWidget);
        expect(find.text('Connected to you'), findsOneWidget);

        await tester.tap(find.byTooltip('Next person'));
        await tester.pumpAndSettle();

        expect(
          find.text('In Friends with you · Not connected to you'),
          findsOneWidget,
        );
      },
    );
  });
}
