import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_button.dart';
import 'package:smartagri/design_system/components/app_progress_bar.dart';
import 'package:smartagri/design_system/components/language_switcher.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/features/dev_gallery/design_gallery_page.dart';

void main() {
  testWidgets('renders every component family', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const DesignGalleryPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Galerie du design system'), findsOneWidget);
    expect(find.byType(AppButton), findsWidgets);
    expect(find.byType(AppProgressBar), findsWidgets);
    expect(find.byType(LanguageSwitcher), findsOneWidget);
  });
}
