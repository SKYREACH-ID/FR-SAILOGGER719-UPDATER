import 'package:flutter_test/flutter_test.dart';
import 'package:sailogger719/models/update_package.dart';

void main() {
  group('UpdatePackage', () {
    test('parses stable 7.19 package data', () {
      final config = UpdatePackage.fromJson(const {
        'ver': '7.19',
        'file': 'sources/SAILOGGER-NEO-7.19.zip',
        'commands': ['echo stable'],
        'rollback_commands': ['echo rollback'],
      });

      expect(config.label, '7.19');
      expect(config.fileName, 'SAILOGGER-NEO-7.19.zip');
      expect(config.downloadPath, 'sources/SAILOGGER-NEO-7.19.zip');
      expect(config.remoteZipPath, '/home/skyflix/SAILOGGER-NEO-7.19.zip');
      expect(config.commands, ['echo stable']);
    });

    test('parses latest package data from API source', () {
      final config = UpdatePackage.fromJson(const {
        'ver': '8.5.1',
        'file': 'sources/SAILOGGER-NEO-LATEST.zip',
        'commands': ['pwd'],
        'rollback_commands': ['pwd'],
      });

      expect(config.label, 'Latest Update');
      expect(config.subtitle, 'v8.5.1');
      expect(config.fileName, 'SAILOGGER-NEO-LATEST.zip');
      expect(config.downloadPath, 'sources/SAILOGGER-NEO-LATEST.zip');
      expect(config.remoteZipPath, '/home/skyflix/SAILOGGER-NEO-LATEST.zip');
      expect(config.commands, ['pwd']);
    });

    test('sorts latest first and other versions descending', () {
      final packages = [
        UpdatePackage.fromJson(const {
          'ver': '7.19',
          'file': 'sources/SAILOGGER-NEO-7.19.zip',
          'commands': [],
          'rollback_commands': [],
        }),
        UpdatePackage.fromJson(const {
          'ver': '8.5.0',
          'file': 'sources/SAILOGGER-NEO-8.5.0.zip',
          'commands': [],
          'rollback_commands': [],
        }),
        UpdatePackage.fromJson(const {
          'ver': '8.5.1',
          'file': 'sources/SAILOGGER-NEO-LATEST.zip',
          'commands': [],
          'rollback_commands': [],
        }),
      ];

      packages.sort(UpdatePackage.compareByVersionDesc);

      expect(packages.map((item) => item.fileName).toList(), [
        'SAILOGGER-NEO-LATEST.zip',
        'SAILOGGER-NEO-8.5.0.zip',
        'SAILOGGER-NEO-7.19.zip',
      ]);
    });
  });
}
