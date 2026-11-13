import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/app_icons.dart';
import 'package:smartagri/design_system/components/app_button.dart';
import 'package:smartagri/design_system/components/app_checkbox_tile.dart';
import 'package:smartagri/design_system/components/app_choice_chips.dart';
import 'package:smartagri/design_system/components/app_search_field.dart';
import 'package:smartagri/design_system/components/app_status_chip.dart';
import 'package:smartagri/design_system/components/app_text_field.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/design_system/tokens.dart';

import 'test_app.dart';

Widget _scaled(Widget child, {double width = 320}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (BuildContext context, Widget? page) {
      final MediaQueryData data = MediaQuery.of(context);
      return MediaQuery(
        data: data.copyWith(textScaler: const TextScaler.linear(1.3)),
        child: page!,
      );
    },
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('buttons expose disabled, loading and normal states', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pumpComponent(
      tester,
      AppButton(label: 'Valider', onPressed: () => taps++),
    );
    expect(find.text('Valider'), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppButton)).height,
      greaterThanOrEqualTo(AppSizes.touchTarget),
    );

    await pumpComponent(
      tester,
      const AppButton(label: 'Désactivé', onPressed: null),
    );
    expect(find.text('Désactivé'), findsOneWidget);

    await tester.pumpWidget(
      testApp(
        AppButton(label: 'Chargement', onPressed: () => taps++, loading: true),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Chargement'), findsNothing);

    await tester.tap(find.byType(AppButton));
    expect(taps, 0);
  });

  testWidgets('text fields keep the label visible and show errors', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpComponent(
      tester,
      AppTextField(controller: controller, hintText: 'Téléphone'),
    );

    expect(find.text('Téléphone'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '+22790000000');
    await tester.pump();
    expect(controller.text, '+22790000000');
    expect(find.text('Téléphone'), findsOneWidget);

    await pumpComponent(
      tester,
      const AppTextField(hintText: 'Erreur', errorText: 'Champ obligatoire.'),
    );
    expect(find.text('Erreur'), findsOneWidget);
    expect(find.text('Champ obligatoire.'), findsOneWidget);
  });

  testWidgets('the password eye button has a 48 dp touch target', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppTextField(hintText: 'Mot de passe', obscure: true),
    );

    final Size size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(AppSizes.touchTarget));
    expect(size.height, greaterThanOrEqualTo(AppSizes.touchTarget));
    expect(find.byIcon(AppIcons.visibility), findsOneWidget);
  });

  testWidgets('checkbox tiles have a 48 dp touch target', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppCheckboxTile(
        label: 'Se souvenir',
        value: false,
        onChanged: (bool value) {},
      ),
    );

    expect(
      tester.getSize(find.byType(AppCheckboxTile)).height,
      greaterThanOrEqualTo(AppSizes.touchTarget),
    );
  });

  testWidgets('choice chips have a 48 dp touch target', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppChoiceChips<String>(
        options: const <AppChoiceOption<String>>[
          AppChoiceOption<String>(value: 'a', label: 'Option A'),
        ],
        value: 'a',
        onChanged: (String value) {},
      ),
    );

    final Size target = tester.getSize(
      find
          .ancestor(of: find.text('Option A'), matching: find.byType(SizedBox))
          .first,
    );
    expect(target.height, AppSizes.touchTarget);
  });

  testWidgets('components do not overflow at a 1.3 text scale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _scaled(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppButton(
              label: 'Faire un diagnostic avec un libellé long',
              onPressed: () {},
              icon: const Icon(AppIcons.scan),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppTextField(
              hintText: 'Numéro de téléphone très long',
              errorText: 'Ce champ est obligatoire.',
            ),
            const SizedBox(height: AppSpacing.md),
            const AppSearchField(hintText: 'Rechercher une parcelle'),
            const SizedBox(height: AppSpacing.md),
            AppCheckboxTile(
              label: 'Partager avec l’administration',
              value: true,
              onChanged: (bool value) {},
            ),
            const SizedBox(height: AppSpacing.md),
            const AppStatusChip(label: 'Attention requise'),
            const SizedBox(height: AppSpacing.md),
            const AppChoiceChips<String>(
              options: <AppChoiceOption<String>>[
                AppChoiceOption<String>(
                  value: 'loam',
                  label: 'Limoneux et profond',
                ),
              ],
              value: 'loam',
              onChanged: _ignore,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

void _ignore(String value) {}
