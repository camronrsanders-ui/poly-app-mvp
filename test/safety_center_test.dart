import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/screens/safety/safety_center_screen.dart';

void main() {
  testWidgets('Safety center explains core consent and access controls',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SafetyCenterScreen()),
    );

    expect(find.text('Safety center'), findsOneWidget);
    expect(find.text('Block at any time'), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    for (final heading in [
      'Report concerning behavior',
      'Private media stays gated',
      'Relationship descriptions are not verification',
      'Adults only',
    ]) {
      await tester.scrollUntilVisible(
        find.text(heading),
        300,
        scrollable: scrollable,
      );
      expect(find.text(heading), findsOneWidget);
    }
  });
}
