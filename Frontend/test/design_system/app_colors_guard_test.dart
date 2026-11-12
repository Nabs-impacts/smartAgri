import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppColors is only referenced by the palette, theme and tokens', () {
    const Set<String> allowed = <String>{
      'lib/design_system/tokens.dart',
      'lib/design_system/theme.dart',
      'lib/design_system/app_palette.dart',
    };
    final List<String> offenders = <String>[];
    final Directory directory = Directory('lib');
    for (final FileSystemEntity entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String normalized = entity.path.replaceAll('\\', '/');
      if (allowed.contains(normalized)) {
        continue;
      }
      if (entity.readAsStringSync().contains('AppColors.')) {
        offenders.add(normalized);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join(', '));
  });
}
