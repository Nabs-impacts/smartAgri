import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Icons is only referenced through app_icons.dart', () {
    final RegExp directIcons = RegExp(r'(?<![A-Za-z])Icons\.');
    final List<String> offenders = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String normalized = entity.path.replaceAll('\\', '/');
      if (normalized == 'lib/design_system/app_icons.dart') {
        continue;
      }
      if (directIcons.hasMatch(entity.readAsStringSync())) {
        offenders.add(normalized);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join(', '));
  });

  test('phosphor_flutter is only imported by app_icons.dart', () {
    final List<String> offenders = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String normalized = entity.path.replaceAll('\\', '/');
      if (normalized == 'lib/design_system/app_icons.dart') {
        continue;
      }
      if (entity.readAsStringSync().contains('phosphor_flutter')) {
        offenders.add(normalized);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join(', '));
  });
}
