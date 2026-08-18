import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polycircle/widgets/conversation_space_header.dart';

void main() {
  testWidgets('conversation space stays compact and names the connection',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConversationSpaceHeader(otherDisplayName: 'Alex'),
        ),
      ),
    );

    expect(find.text('Your conversation space'), findsOneWidget);
    expect(
      find.textContaining('A private space for you and Alex'),
      findsOneWidget,
    );
    expect(find.text('A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
