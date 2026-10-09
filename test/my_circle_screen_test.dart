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

CircleMembershipSnapshot snapshot({
  List<CircleSummary> circles = const <CircleSummary>[],
  List<CircleInviteSummary> invites = const <CircleInviteSummary>[],
}) {
  return CircleMembershipSnapshot(
    circles: circles,
    invites: invites,
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
}) async {
  tester.view.physicalSize = const Size(1100, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
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
}
