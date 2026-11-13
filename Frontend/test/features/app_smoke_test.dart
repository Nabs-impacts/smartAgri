import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartagri/core/router/app_router.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/features/dev_gallery/design_gallery_page.dart';

import 'app_test_utils.dart';

Future<void> _pumpShell(WidgetTester tester, ThemeData theme) async {
  final ProviderContainer container = await buildTestContainer(
    meRepository: FakeMeRepository(sampleMeData()),
  );
  final GoRouter router = container.read(routerProvider);
  await tester.pumpWidget(testRouterApp(container, router, theme: theme));
  await tester.pumpAndSettle();
}

void main() {
  for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('main pages render in the ${theme.brightness.name} theme', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, theme);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('app_bottom_nav_1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('app_bottom_nav_2')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('app_bottom_nav_0')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the gallery renders in the ${theme.brightness.name} theme', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: theme, home: const DesignGalleryPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Galerie du design system'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
