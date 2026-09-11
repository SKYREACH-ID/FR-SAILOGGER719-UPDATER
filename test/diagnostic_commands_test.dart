import 'package:flutter_test/flutter_test.dart';
import 'package:sailogger719/screens/diagnostic_commands.dart';

void main() {
  group('diagnostic command helpers', () {
    test('extracts command version from versi output line', () {
      expect(
        extractCommandVersion(
          'VERSI : 1.0.3\n\nRunning ... ... ...\n',
        ),
        '1.0.3',
      );
    });

    test('detects ARR202 status report presence', () {
      expect(
        buildArr202Flag(
          '{'
          '"status": {'
          '"202": "Modbus tidak terhubung/merespon."'
          '}'
          '}',
        ),
        'Y',
      );
      expect(
        buildArr202Flag(
          '{'
          '"status": {'
          '"201": "Koneksi tidak ditemukan/konek."'
          '}'
          '}',
        ),
        'N',
      );
    });

    test('formats WIB timestamp tokens', () {
      expect(
        formatWibTimestamp(DateTime.utc(2026, 7, 31, 8, 24, 53)),
        ('20260731', '152453'),
      );
    });

    test('builds upgraded failed sms entry', () {
      expect(
        buildFailedSmsUpgradeEntry(
          deviceId: '57119',
          thrchVersion: '8.5.3.1',
          arr202Flag: 'Y',
          iotrVersion: '1.0.3',
          rdsmsVersion: '4.0.3',
          timestampWib: DateTime.utc(2026, 7, 31, 8, 24, 53),
        ),
        '1005||00882161900000||SLNK# 57119 THRCH>8.5.3.1 - ARR202>Y - IOTR>1.0.3 - RDSMS>4.0.3 20260731 152453 UPGRADED',
      );
    });

    test('builds append command without newline', () {
      expect(
        buildFailedSmsUpgradeAppendCommand(
          "1005||00882161900000||SLNK# 57119 THRCH>8.5.3.1 - ARR202>Y - IOTR>1.0.3 - RDSMS>4.0.3 20260731 152453 UPGRADED",
        ),
        "printf '%s' '1005||00882161900000||SLNK# 57119 THRCH>8.5.3.1 - ARR202>Y - IOTR>1.0.3 - RDSMS>4.0.3 20260731 152453 UPGRADED' >> /var/Python/log/FailedSMS.log",
      );
    });

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

    test('builds failed sms download list command using file existence checks', () {
      expect(
        buildFailedSmsDownloadListCommand(),
        'sh -lc \'for path in /var/Python/log/FailedSMS.log*; do [ -f "\$path" ] && printf "%s\\\\n" "\$path"; done\'',
      );
    });

    test('builds failed sms download success summary', () {
      expect(
        buildFailedSmsDownloadSuccessMessage(2),
        '2 FailedSMS log files downloaded.',
      );
      expect(
        buildFailedSmsDownloadSuccessMessage(1),
        '1 FailedSMS log file downloaded.',
      );
    });

    test('builds failed sms download location details', () {
      expect(
        buildFailedSmsDownloadLocationDetails(
          directoryPath: 'Download/sailogger719',
          fileNames: ['FailedSMS.log', 'FailedSMS.log--2026-07-16'],
        ),
        'Folder:\n'
        'Download/sailogger719\n\n'
        'Files:\n'
        'FailedSMS.log\n'
        'FailedSMS.log--2026-07-16',
      );
    });

    test('builds scoped storage download path inside app folder', () {
      expect(
        buildFailedSmsDownloadRelativePath(),
        'Download/sailogger719',
      );
    });

    test('requires legacy write external storage only on android 9 and below', () {
      expect(
        requiresLegacyWriteExternalStorageForFailedSmsDownload(
          isAndroid: true,
          androidSdkInt: 28,
        ),
        isTrue,
      );
      expect(
        requiresLegacyWriteExternalStorageForFailedSmsDownload(
          isAndroid: true,
          androidSdkInt: 29,
        ),
        isFalse,
      );
      expect(
        requiresLegacyWriteExternalStorageForFailedSmsDownload(
          isAndroid: false,
          androidSdkInt: 34,
        ),
        isFalse,
      );
    });

    test('sanitizes invalid failed sms file names while keeping original basename', () {
      expect(
        sanitizeFailedSmsDownloadFileName(' /var/Python/log/bad:name?.log '),
        'bad_name_.log',
      );
      expect(
        sanitizeFailedSmsDownloadFileName('../'),
        'FailedSMS.log',
      );
    });

    test('builds console password from date, device id, and hour multiplier', () {
      expect(
        buildConsolePassword(
          now: DateTime(2026, 7, 27, 14),
          deviceIdRaw: '50008',
        ),
        '320818',
      );
    });

    test('builds console password after normalizing device id digits', () {
      expect(
        buildConsolePassword(
          now: DateTime(2026, 7, 27, 14),
          deviceIdRaw: ' ID-IoT: 50-008 ',
        ),
        '320818',
      );
    });

    test('tracks console authorization for the current app session only', () {
      ConsoleAccessSession.resetForTest();
      expect(ConsoleAccessSession.isAuthorized, isFalse);

      ConsoleAccessSession.authorize();
      expect(ConsoleAccessSession.isAuthorized, isTrue);

      ConsoleAccessSession.resetForTest();
      expect(ConsoleAccessSession.isAuthorized, isFalse);
    });
  });
}
