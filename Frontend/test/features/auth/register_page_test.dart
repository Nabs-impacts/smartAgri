import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/i18n/app_language.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/design_system/components/app_button.dart';
import 'package:smartagri/design_system/components/app_checkbox_tile.dart';
import 'package:smartagri/design_system/components/app_error_banner.dart';
import 'package:smartagri/features/auth/data/pending_consents_store.dart';
import 'package:smartagri/features/auth/domain/auth_purpose.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';
import 'package:smartagri/features/auth/domain/otp_args.dart';

import 'auth_test_harness.dart';

void setTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> fillRegister(
  WidgetTester tester, {
  String name = 'Amina Diallo',
  String phone = '90203040',
  String password = 'secret123',
  String confirmation = 'secret123',
}) async {
  await tester.enterText(fieldByKey('register_name_field'), name);
  await tester.enterText(fieldByKey('register_phone_field'), phone);
  await tester.enterText(fieldByKey('register_password_field'), password);
  await tester.enterText(fieldByKey('register_confirm_field'), confirmation);
  await tester.pump();
}

Future<void> acceptMandatory(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('register_consent_terms')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('register_consent_privacy')));
  await tester.pump();
}

Future<void> submitRegister(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('register_submit')));
  await tester.tap(find.byKey(const Key('register_submit')));
  await tester.pump();
}

void main() {
  testWidgets('keeps the submit button disabled without both consents', (
    WidgetTester tester,
  ) async {
    setTallSurface(tester);
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/register',
    );

    AppButton button = tester.widget<AppButton>(
      find.byKey(const Key('register_submit')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(const Key('register_consent_terms')));
    await tester.pump();
    button = tester.widget<AppButton>(find.byKey(const Key('register_submit')));
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(const Key('register_consent_privacy')));
    await tester.pump();
    button = tester.widget<AppButton>(find.byKey(const Key('register_submit')));
    expect(button.onPressed, isNotNull);
    expect(harness.repository.registerCalls, 0);
  });

  testWidgets('leaves the optional consents unchecked by default', (
    WidgetTester tester,
  ) async {
    setTallSurface(tester);
    await pumpAuthApp(tester, initialLocation: '/register');

    final AppCheckboxTile data = tester.widget<AppCheckboxTile>(
      find.byKey(const Key('register_consent_data')),
    );
    final AppCheckboxTile research = tester.widget<AppCheckboxTile>(
      find.byKey(const Key('register_consent_research')),
    );
    expect(data.value, isFalse);
    expect(research.value, isFalse);
  });

  testWidgets('validates every field and the confirmation', (
    WidgetTester tester,
  ) async {
    setTallSurface(tester);
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/register',
    );
    await acceptMandatory(tester);

    await fillRegister(
      tester,
      name: 'A',
      phone: '123',
      password: 'court',
      confirmation: 'autre',
    );
    await submitRegister(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Le nom complet doit contenir entre 2 et 120 caractères.'),
      findsOneWidget,
    );
    expect(
      find.text('Veuillez saisir un numéro de téléphone valide.'),
      findsOneWidget,
    );
    expect(
      find.text('Le mot de passe doit contenir entre 8 et 128 caractères.'),
      findsOneWidget,
    );
    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    expect(harness.repository.registerCalls, 0);
  });

  testWidgets('rejects a password longer than 128 characters', (
    WidgetTester tester,
  ) async {
    setTallSurface(tester);
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/register',
    );
    await acceptMandatory(tester);
    final String longPassword = 'a' * 129;
    await fillRegister(
      tester,
      password: longPassword,
      confirmation: longPassword,
    );

    await submitRegister(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Le mot de passe doit contenir entre 8 et 128 caractères.'),
      findsOneWidget,
    );
    expect(harness.repository.registerCalls, 0);
  });

  testWidgets('registers, stores consents and opens the OTP page', (
    WidgetTester tester,
  ) async {
    setTallSurface(tester);
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/register',
    );
    await harness.container
        .read(languageControllerProvider.notifier)
        .set(AppLanguage.ha);
    await tester.pump();
    await acceptMandatory(tester);
    await fillRegister(tester);

    await submitRegister(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(harness.repository.registerCalls, 1);
    expect(harness.repository.lastFullName, 'Amina Diallo');
    expect(harness.repository.lastPhone, '90 20 30 40');
    expect(harness.repository.lastPassword, 'secret123');
    expect(harness.repository.lastLanguage, 'ha');
    expect(harness.router.state.uri.path, '/otp');
    final OtpArgs args = harness.router.state.extra! as OtpArgs;
    expect(args.phone, '+22790203040');
    expect(args.purpose, AuthPurpose.verifyPhone);

    final List<ConsentChoice> stored = harness.container
        .read(pendingConsentsStoreProvider)
        .read();
    expect(stored, hasLength(4));
    expect(stored.map((ConsentChoice choice) => choice.type), <ConsentType>[
      ConsentType.terms,
      ConsentType.privacy,
      ConsentType.dataSharingGov,
      ConsentType.research,
    ]);
    expect(stored[0].accepted, isTrue);
    expect(stored[1].accepted, isTrue);
    expect(stored[2].accepted, isFalse);
    expect(stored[3].accepted, isFalse);
  });

  testWidgets('shows a generic error and stays on the page', (
    WidgetTester tester,
  ) async {
    setTallSurface(tester);
    final FakeAuthRepository repository = FakeAuthRepository()
      ..registerError = const ApiException(
        code: 'UNKNOWN_ERROR',
        message: 'Erreur serveur.',
      );
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/register',
      repository: repository,
    );
    await acceptMandatory(tester);
    await fillRegister(tester);

    await submitRegister(tester);
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorBanner), findsOneWidget);
    expect(
      find.text('Une erreur est survenue. Veuillez réessayer.'),
      findsOneWidget,
    );
    expect(harness.router.state.uri.path, '/register');
  });

  testWidgets('explains an existing phone number and offers the login link', (
    WidgetTester tester,
  ) async {
    setTallSurface(tester);
    final FakeAuthRepository repository = FakeAuthRepository()
      ..registerError = const ApiException(
        code: 'CONFLICT',
        message: 'Ce numéro de téléphone est déjà enregistré.',
        statusCode: 409,
      );
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/register',
      repository: repository,
    );
    await acceptMandatory(tester);
    await fillRegister(tester);

    await submitRegister(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Ce numéro de téléphone est déjà utilisé.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('register_go_login')), findsOneWidget);

    await tester.tap(find.byKey(const Key('register_go_login')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/login');
  });

  testWidgets('opens the provisional legal pages from the read buttons', (
    WidgetTester tester,
  ) async {
    setTallSurface(tester);
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/register',
    );

    await tester.tap(find.byKey(const Key('register_read_terms')));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/legal/terms');
    expect(find.text('Conditions d\'utilisation'), findsOneWidget);

    harness.router.go('/register');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('register_read_privacy')));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/legal/privacy');
    expect(find.text('Politique de confidentialité'), findsOneWidget);
  });
}
