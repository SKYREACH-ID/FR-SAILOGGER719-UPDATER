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

    test('builds combined failed sms summary', () {
      expect(
        buildFailedSmsSummary(
          top10: 'top-line-1\ntop-line-2',
          bottom10: 'bottom-line-1',
          lineCount: '42 /var/Python/log/FailedSMS.log',
        ),
        'Count:\n'
        '42 /var/Python/log/FailedSMS.log\n\n'
        'Top 10:\n'
        'top-line-1\n'
        'top-line-2\n\n'
        'Bottom 10:\n'
        'bottom-line-1',
      );
    });

    test('builds failed sms clear command with archive suffix', () {
      expect(
        buildFailedSmsClearCommand(DateTime(2026, 7, 8)),
        'mv /var/Python/log/FailedSMS.log /var/Python/log/FailedSMS.log--2026-07-08 && cat /dev/null > /var/Python/log/FailedSMS.log',
      );
    });
  });
}
