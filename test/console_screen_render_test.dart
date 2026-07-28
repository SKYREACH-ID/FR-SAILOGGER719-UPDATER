import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailogger719/screens/console_screen.dart';

void main() {
  testWidgets('console screen renders terminal header and shortcut keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ConsoleScreen(
          host: '127.0.0.1',
          port: 22,
          username: 'tester',
          password: 'secret',
          autoConnect: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Console'), findsOneWidget);
    expect(find.text('Ctrl'), findsOneWidget);
    expect(find.text('Alt'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);
    expect(find.text('Tab'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
  });
}
