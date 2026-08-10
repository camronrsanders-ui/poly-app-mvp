import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/safety/safety_center_screen.dart';

void main() {
  testWidgets('Safety center explains core consent and access controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SafetyCenterScreen()),
    );

    expect(find.text('Safety center'), findsOneWidget);
    expect(find.text('Block at any time'), findsOneWidget);
    expect(find.text('End a connection'), findsOneWidget);
    expect(find.text('Report concerning behavior'), findsOneWidget);
    expect(find.text('Private media stays gated'), findsOneWidget);
    expect(find.text('Adults only'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Relationship descriptions are not verification'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Relationship descriptions are not verification'), findsOneWidget);
  });
}
