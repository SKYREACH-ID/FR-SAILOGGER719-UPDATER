import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sailogger719/widgets/app_overlay_message.dart';

void main() {
  testWidgets('AppOverlayMessage shows and replaces previous message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      ),
    );

    final context = tester.element(find.byType(SizedBox));

    AppOverlayMessage.show(context, message: 'Pesan pertama');
    await tester.pump();

    expect(find.text('Pesan pertama'), findsOneWidget);

    AppOverlayMessage.show(context, message: 'Pesan kedua');
    await tester.pump();

    expect(find.text('Pesan pertama'), findsNothing);
    expect(find.text('Pesan kedua'), findsOneWidget);

    AppOverlayMessage.hide();
    await tester.pump();
  });

  testWidgets('AppOverlayMessage renders optional action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox.shrink()),
      ),
    );

    final context = tester.element(find.byType(SizedBox));

    AppOverlayMessage.show(
      context,
      message: 'Download selesai',
      actionLabel: 'LIHAT',
      onAction: () {
        tapped = true;
      },
    );
    await tester.pump();

    expect(find.text('LIHAT'), findsOneWidget);

    await tester.tap(find.text('LIHAT'));
    await tester.pump();

    expect(tapped, isTrue);
    expect(find.text('Download selesai'), findsNothing);

    AppOverlayMessage.hide();
    await tester.pump();
  });
}
