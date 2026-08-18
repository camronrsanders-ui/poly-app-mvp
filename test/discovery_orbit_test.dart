import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/widgets/discovery_orbit.dart';

void main() {
  testWidgets('orbit rotates between profiles and opens the selected world',
      (tester) async {
    final viewed = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscoveryOrbit(
            profiles: const [
              {
                'uid': 'alex',
                'displayName': 'Alex',
                'age': 30,
                'city': 'Boston',
                'region': 'MA',
                'headline': 'Coffee, community, and travel',
                'intentionTags': ['Friendship'],
              },
              {
                'uid': 'blair',
                'displayName': 'Blair',
                'age': 31,
                'city': 'Cambridge',
                'region': 'MA',
                'headline': 'Building intentional connections',
                'intentionTags': ['Dating'],
              },
            ],
            imageBuilder: (_) => const ColoredBox(color: Colors.blue),
            onViewProfile: (profile) => viewed.add(profile['uid'] as String),
            onLike: (_) {},
            onPass: (_) {},
            isActing: (_) => false,
          ),
        ),
      ),
    );

    expect(find.text('Alex, 30'), findsOneWidget);

    await tester.drag(find.byType(DiscoveryOrbit), const Offset(-180, 0));
    await tester.pumpAndSettle();

    expect(find.text('Blair, 31'), findsOneWidget);

    await tester.tap(find.text('Enter their profile world'));
    await tester.pump();

    expect(viewed, ['blair']);
  });

  testWidgets('single-profile orbit stays usable without rotation',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscoveryOrbit(
            profiles: const [
              {
                'uid': 'alex',
                'displayName': 'Alex',
                'age': 30,
              },
            ],
            imageBuilder: (_) => const ColoredBox(color: Colors.blue),
            onViewProfile: (_) {},
            onLike: (_) {},
            onPass: (_) {},
            isActing: (_) => false,
          ),
        ),
      ),
    );

    expect(find.text('Alex, 30'), findsOneWidget);
    expect(
      find.text('Tap the profile to enter their world'),
      findsOneWidget,
    );
  });
}
