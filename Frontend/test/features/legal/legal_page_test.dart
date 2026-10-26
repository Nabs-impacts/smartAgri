import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/features/legal/legal_page.dart';

Future<void> pumpLegal(WidgetTester tester, LegalDocument document) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: LegalPage(document: document),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the provisional banner and the terms paragraphs', (
    WidgetTester tester,
  ) async {
    await pumpLegal(tester, LegalDocument.terms);

    expect(find.text('Conditions d\'utilisation'), findsOneWidget);
    expect(
      find.text(
        'Texte provisoire : le document juridique définitif sera publié avant le lancement.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Ces conditions décrivent'), findsOneWidget);
    expect(find.textContaining('En utilisant l\'application'), findsOneWidget);
  });

  testWidgets('shows the privacy paragraphs', (WidgetTester tester) async {
    await pumpLegal(tester, LegalDocument.privacy);

    expect(find.text('Politique de confidentialité'), findsOneWidget);
    expect(find.textContaining('Cette politique explique'), findsOneWidget);
    expect(find.textContaining('Vos données personnelles'), findsOneWidget);
  });
}
