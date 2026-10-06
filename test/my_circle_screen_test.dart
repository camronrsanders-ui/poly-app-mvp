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
      final circle = CircleSummary(
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
}
