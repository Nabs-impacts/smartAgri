import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('components use design tokens for radii and colors', () {
    final RegExp hexColor = RegExp(r'Color\(0x');
    final RegExp numericRadius = RegExp(r'Radius\.circular\(\s*[0-9]');
    final RegExp colorLiteral = RegExp(r'Colors\.(?!transparent)');
    final List<String> offenders = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib/design_system/components',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String content = entity.readAsStringSync();
      if (hexColor.hasMatch(content) ||
          numericRadius.hasMatch(content) ||
          colorLiteral.hasMatch(content)) {
        offenders.add(entity.path.replaceAll('\\', '/'));
      }
    }

    expect(offenders, isEmpty, reason: offenders.join(', '));
  });
}
