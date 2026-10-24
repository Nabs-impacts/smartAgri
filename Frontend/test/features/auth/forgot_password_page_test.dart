import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/design_system/components/app_error_banner.dart';
import 'package:smartagri/design_system/components/app_text_button.dart';
import 'package:smartagri/features/auth/domain/auth_purpose.dart';

import 'auth_test_harness.dart';

Future<void> openResetStep(
  WidgetTester tester,
  AuthHarness harness, {
  String phone = '90203040',
}) async {
  await tester.enterText(fieldByKey('forgot_phone_field'), phone);
  await tester.tap(find.byKey(const Key('forgot_send_code')));
  await tester.pumpAndSettle();
}

Future<void> fillReset(
  WidgetTester tester, {
  String code = '123456',
  String password = 'nouveau123',
  String confirmation = 'nouveau123',
}) async {
  await tester.enterText(fieldByKey('forgot_code_field'), code);
  await tester.enterText(fieldByKey('forgot_password_field'), password);
  await tester.enterText(fieldByKey('forgot_confirmation_field'), confirmation);
}

void main() {
  testWidgets('validates the phone before requesting a code', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/forgot-password',
    );

    await tester.enterText(fieldByKey('forgot_phone_field'), '123');
    await tester.tap(find.byKey(const Key('forgot_send_code')));
    await tester.pumpAndSettle();

    expect(
      find.text('Veuillez saisir un numéro de téléphone valide.'),
      findsOneWidget,
    );
    expect(harness.repository.requestOtpCalls, 0);
  });

  testWidgets('requests a reset code and shows the second step', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/forgot-password',
    );

    await openResetStep(tester, harness);

    expect(harness.repository.requestOtpCalls, 1);
    expect(harness.repository.lastPhone, '90 20 30 40');
    expect(harness.repository.lastPurpose, AuthPurpose.resetPassword);
    expect(find.byKey(const Key('forgot_code_field')), findsOneWidget);
    expect(find.byKey(const Key('forgot_password_field')), findsOneWidget);
    expect(find.text('Un code de vérification a été envoyé.'), findsOneWidget);
  });

  testWidgets('validates the code, the password and the confirmation', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/forgot-password',
    );
    await openResetStep(tester, harness);

    await tester.tap(find.byKey(const Key('forgot_change_password')));
    await tester.pumpAndSettle();

    expect(find.text('Veuillez saisir le code reçu.'), findsOneWidget);
    expect(
      find.text('Le mot de passe doit contenir au moins 8 caractères.'),
      findsOneWidget,
    );

    await fillReset(tester, code: '123', password: 'court');
    await tester.tap(find.byKey(const Key('forgot_change_password')));
    await tester.pumpAndSettle();

    expect(find.text('Le code doit contenir 6 chiffres.'), findsOneWidget);

    await fillReset(
      tester,
      password: 'nouveau123',
      confirmation: 'different123',
    );
    await tester.tap(find.byKey(const Key('forgot_change_password')));
    await tester.pumpAndSettle();

    expect(
      find.text('Les mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    expect(harness.repository.resetPasswordCalls, 0);
  });

  testWidgets('runs the resend countdown before enabling the button', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/forgot-password',
    );
    await openResetStep(tester, harness);

    expect(find.text('Renvoyer le code (60 s)'), findsOneWidget);
    expect(
      tester
          .widget<AppTextButton>(find.byKey(const Key('forgot_resend')))
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Renvoyer le code (59 s)'), findsOneWidget);

    for (int index = 0; index < 60; index++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(
      tester
          .widget<AppTextButton>(find.byKey(const Key('forgot_resend')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('forgot_resend')));
    await tester.pumpAndSettle();
    expect(harness.repository.requestOtpCalls, 2);

    for (int index = 0; index < 60; index++) {
      await tester.pump(const Duration(seconds: 1));
    }
  });

  testWidgets('resets the password and returns to login prefilled', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/forgot-password',
    );
    await openResetStep(tester, harness);
    await fillReset(tester);

    await tester.tap(find.byKey(const Key('forgot_change_password')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Votre mot de passe a été modifié. Vous pouvez vous connecter.',
      ),
      findsOneWidget,
    );
    expect(harness.repository.resetPasswordCalls, 1);
    expect(harness.repository.lastCode, '123456');
    expect(harness.repository.lastNewPassword, 'nouveau123');

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/login');
    expect(fieldText(tester, 'login_phone_field'), '90 20 30 40');
  });

  testWidgets('shows a request error without leaving the first step', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    repository.requestOtpError = ApiException.network();
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/forgot-password',
      repository: repository,
    );

    await openResetStep(tester, harness);

    expect(find.byType(AppErrorBanner), findsOneWidget);
    expect(
      find.text(
        'Impossible de joindre le serveur. Vérifiez votre connexion internet.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('forgot_code_field')), findsNothing);
  });

  testWidgets('shows a reset error on the second step', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    repository.resetPasswordError = const ApiException(
      code: 'UNAUTHORIZED',
      message: 'Code invalide ou expiré.',
      statusCode: 401,
    );
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/forgot-password',
      repository: repository,
    );
    await openResetStep(tester, harness);
    await fillReset(tester);

    await tester.tap(find.byKey(const Key('forgot_change_password')));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorBanner), findsOneWidget);
    expect(
      find.text('Le code de vérification est invalide ou expiré.'),
      findsOneWidget,
    );
    expect(harness.router.state.uri.path, '/forgot-password');
  });
}
