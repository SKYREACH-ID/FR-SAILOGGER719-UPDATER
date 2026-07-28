import 'package:flutter_test/flutter_test.dart';

import 'package:sailogger719/main.dart';

void main() {
  testWidgets('home screen shows primary action buttons', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('START UPDATE'), findsOneWidget);
    expect(find.text('DIAGNOSTIC'), findsOneWidget);
    expect(find.text('DEVICE CHECK'), findsOneWidget);
    expect(find.text('SAT-COMM'), findsOneWidget);
    expect(find.text('CONSOLE'), findsOneWidget);
  });
}
