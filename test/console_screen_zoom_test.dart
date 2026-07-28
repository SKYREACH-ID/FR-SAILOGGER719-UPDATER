import 'package:flutter_test/flutter_test.dart';
import 'package:sailogger719/screens/console_screen.dart';

void main() {
  test('console terminal font size clamps to configured bounds', () {
    expect(clampConsoleTerminalFontSize(5), 7);
    expect(clampConsoleTerminalFontSize(9.5), 9.5);
    expect(clampConsoleTerminalFontSize(20), 13);
  });

  test('console terminal font size scales and respects zoom limits', () {
    expect(
      scaleConsoleTerminalFontSize(baseFontSize: 7, gestureScale: 0.5),
      7,
    );
    expect(
      scaleConsoleTerminalFontSize(baseFontSize: 7, gestureScale: 1.5),
      10.5,
    );
    expect(
      scaleConsoleTerminalFontSize(baseFontSize: 10, gestureScale: 2),
      13,
    );
  });
}
