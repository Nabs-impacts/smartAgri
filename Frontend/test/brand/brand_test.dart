import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _libFiles() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList();
}

void main() {
  test('no SmartAgri brand remains in lib outside the allowed identifiers', () {
    const List<String> allowed = <String>[
      'com.smartagri.app',
      'smartagri.sqlite',
    ];
    final List<String> offenders = <String>[];
    for (final File file in _libFiles()) {
      String content = file.readAsStringSync();
      for (final String identifier in allowed) {
        content = content.replaceAll(identifier, '');
      }
      if (content.toLowerCase().contains('smartagri')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('no logo_leaf asset is referenced in lib', () {
    final List<String> offenders = <String>[];
    for (final File file in _libFiles()) {
      if (file.readAsStringSync().contains('logo_leaf')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('the export file uses the GonaTa name', () {
    final String source = File(
      'lib/features/privacy/data/privacy_repository.dart',
    ).readAsStringSync();
    expect(source, contains(r'gonata-donnees-$year-$month-$day.json'));
    expect(source, isNot(contains('smartagri-donnees')));
  });
}
