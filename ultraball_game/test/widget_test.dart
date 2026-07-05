@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ultraball_game/main.dart';

void main() {
  testWidgets('App starts with settings screen', (WidgetTester tester) async {
    await tester.pumpWidget(const UltraballApp());
    expect(find.text('ULTRABALL'), findsOneWidget);
  });
}
