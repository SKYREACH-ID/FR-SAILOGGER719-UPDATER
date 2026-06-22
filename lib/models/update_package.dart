class UpdatePackage {
  const UpdatePackage({
    required this.version,
    required this.file,
    required this.commands,
    required this.rollbackCommands,
    this.checksum,
    this.filesize,
    this.requirements = const [],
  });

  const UpdatePackage.fallback719()
      : version = '7.19',
        file = 'sources/SAILOGGER-NEO-7.19.zip',
        commands = const [],
        rollbackCommands = const [],
        checksum = null,
        filesize = null,
        requirements = const [];

  final String version;
  final String file;
  final String? checksum;
  final int? filesize;
  final List<String> requirements;
  final List<String> commands;
  final List<String> rollbackCommands;

  factory UpdatePackage.fromJson(Map<String, dynamic> json) {
    return UpdatePackage(
      version: (json['ver'] ?? '').toString(),
      file: (json['file'] ?? '').toString(),
      checksum: json['checksum']?.toString(),
      filesize: json['filesize'] is int
          ? json['filesize'] as int
          : int.tryParse('${json['filesize']}'),
      requirements: _toStringList(json['requirements']),
      commands: _toStringList(json['commands']),
      rollbackCommands: _toStringList(json['rollback_commands']),
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  bool get isLatest => file.toUpperCase().contains('LATEST');

  String get fileName {
    final normalized = file.trim();
    if (normalized.isEmpty) return '';
    return normalized.split('/').last;
  }

  String get remoteZipPath => '/home/skyflix/$fileName';

  String get downloadPath => file;

  String get label => isLatest ? 'Latest Update' : version;

  String get subtitle =>
      isLatest && version.isNotEmpty ? 'v$version' : fileName;

  static int compareByVersionDesc(UpdatePackage a, UpdatePackage b) {
    if (a.isLatest != b.isLatest) {
      return a.isLatest ? -1 : 1;
    }

    final aParts = _parseVersionParts(a.version);
    final bParts = _parseVersionParts(b.version);
    final maxLength = aParts.length > bParts.length ? aParts.length : bParts.length;

    for (var index = 0; index < maxLength; index++) {
      final aValue = index < aParts.length ? aParts[index] : 0;
      final bValue = index < bParts.length ? bParts[index] : 0;
      if (aValue != bValue) {
        return bValue.compareTo(aValue);
      }
    }

    return b.fileName.compareTo(a.fileName);
  }

  static List<int> _parseVersionParts(String version) {
    final matches = RegExp(r'\d+').allMatches(version);
    return matches
        .map((match) => int.tryParse(match.group(0) ?? '') ?? 0)
        .toList();
  }
}
