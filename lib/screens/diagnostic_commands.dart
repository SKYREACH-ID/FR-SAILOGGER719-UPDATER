class SailinkStartConfig {
  const SailinkStartConfig({
    required this.modeLabel,
    required this.command,
    required this.log,
  });

  final String modeLabel;
  final String command;
  final String log;
}

const String failedSmsLogPath = '/var/Python/log/FailedSMS.log';

String buildFailedSmsSummary({
  required String top10,
  required String bottom10,
  required String lineCount,
}) {
  return 'Count:\n'
      '${lineCount.trim()}\n\n'
      'Top 10:\n'
      '${top10.trim()}\n\n'
      'Bottom 10:\n'
      '${bottom10.trim()}';
}

String buildFailedSmsClearCommand(DateTime now) {
  final year = now.year.toString().padLeft(4, '0');
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  final suffix = '$year-$month-$day';
  return 'mv $failedSmsLogPath $failedSmsLogPath--$suffix && '
      'cat /dev/null > $failedSmsLogPath';
}

bool isBenignSailinkStderr(String raw) {
  final normalized = raw.toLowerCase();
  return normalized.contains('warning') &&
      normalized.contains('failed to remove temporary directory');
}

String formatSailinkStderrLabel(String raw) {
  return isBenignSailinkStderr(raw) ? '[warning] ' : '[stderr] ';
}

String detectSatMode(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized.contains('thuraya')) {
    return 'THURAYA';
  }
  if (normalized.contains('iridium')) {
    return 'IRIDIUM';
  }
  return 'UNKNOWN';
}

String satStatusCommandForMode(String satModeRaw) {
  switch (detectSatMode(satModeRaw)) {
    case 'IRIDIUM':
      return 'cat /var/Python/Status/Iridium.json';
    case 'THURAYA':
      return 'cat /var/Python/Status/Thuraya.json';
    default:
      return '';
  }
}

SailinkStartConfig sailinkStartConfigForMode(String satModeRaw) {
  switch (detectSatMode(satModeRaw)) {
    case 'THURAYA':
      return const SailinkStartConfig(
        modeLabel: 'THURAYA',
        command: 'sleep 2 && /var/Python/SKYREACH-TH-IoT-GINTLIVE.RUN',
        log: 'running SAILINK -THURAYA:\n- SKYREACH-TH-IoT-GINTLIVE.RUN',
      );
    case 'IRIDIUM':
    default:
      return const SailinkStartConfig(
        modeLabel: 'IRIDIUM',
        command: 'sleep 2 && /var/Python/SKYREACH-GL-IoT-GINTLIVE.RUN',
        log: 'running SAILINK -IRIDIUM:\n- SKYREACH-GL-IoT-GINTLIVE.RUN',
      );
  }
}
