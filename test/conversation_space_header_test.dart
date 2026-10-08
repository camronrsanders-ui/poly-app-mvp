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

    expect(find.text('Alex'), findsOneWidget);
    expect(find.textContaining('Create a world together'), findsOneWidget);
    expect(find.text('Your conversation space'), findsNothing);
    expect(find.text('A'), findsOneWidget);

    final size = tester.getSize(
      find.byKey(const Key('conversation-space-identity')),
    );
    expect(size.height, lessThanOrEqualTo(56));
    expect(tester.takeException(), isNull);
  });
}
