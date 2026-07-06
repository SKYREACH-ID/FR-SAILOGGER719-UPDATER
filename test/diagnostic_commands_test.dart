import 'package:flutter_test/flutter_test.dart';
import 'package:sailogger719/screens/diagnostic_commands.dart';

void main() {
  group('diagnostic command helpers', () {
    test('maps SAT mode to SAT status command', () {
      expect(
        satStatusCommandForMode('IRIDIUM'),
        'cat /var/Python/Status/Iridium.json',
      );
      expect(
        satStatusCommandForMode('THURAYA'),
        'cat /var/Python/Status/Thuraya.json',
      );
      expect(satStatusCommandForMode('UNKNOWN'), '');
    });

    test('builds start command and log for iridium', () {
      final config = sailinkStartConfigForMode('iridium');

      expect(
        config.command,
        'sleep 2 && /var/Python/SKYREACH-GL-IoT-GINTLIVE.RUN',
      );
      expect(
        config.log,
        'running SAILINK -IRIDIUM:\n- SKYREACH-GL-IoT-GINTLIVE.RUN',
      );
    });

    test('builds start command and log for thuraya', () {
      final config = sailinkStartConfigForMode('thuraya');

      expect(
        config.command,
        'sleep 2 && /var/Python/SKYREACH-TH-IoT-GINTLIVE.RUN',
      );
      expect(
        config.log,
        'running SAILINK -THURAYA:\n- SKYREACH-TH-IoT-GINTLIVE.RUN',
      );
    });

    test('detects benign sailink stderr warning', () {
      expect(
        isBenignSailinkStderr(
          '[PYI-2721:WARNING] Failed to remove temporary directory: /tmp/_MEIDgWTQW',
        ),
        isTrue,
      );
      expect(
        formatSailinkStderrLabel(
          '[PYI-2721:WARNING] Failed to remove temporary directory: /tmp/_MEIDgWTQW',
        ),
        '[warning] ',
      );
    });

    test('keeps real stderr as stderr label', () {
      expect(
        isBenignSailinkStderr('Traceback: something broke'),
        isFalse,
      );
      expect(
        formatSailinkStderrLabel('Traceback: something broke'),
        '[stderr] ',
      );
    });
  });
}
