import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/design_system/components/app_button.dart';
import 'package:smartagri/design_system/components/app_checkbox_tile.dart';
import 'package:smartagri/design_system/components/app_error_banner.dart';
import 'package:smartagri/features/auth/domain/auth_purpose.dart';
import 'package:smartagri/features/auth/domain/auth_session.dart';
import 'package:smartagri/features/auth/domain/otp_args.dart';

import 'auth_test_harness.dart';

Future<void> submitLogin(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('login_submit')));
  await tester.pumpAndSettle();
}

Future<void> fillLogin(
  WidgetTester tester, {
  String phone = '90203040',
  String password = 'secret123',
}) async {
  await tester.enterText(fieldByKey('login_phone_field'), phone);
  await tester.enterText(fieldByKey('login_password_field'), password);
}

void main() {
  testWidgets('validates the phone and the password', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(tester);

    await tester.enterText(fieldByKey('login_phone_field'), '123');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Veuillez saisir un numéro de téléphone valide.'),
      findsOneWidget,
    );
    expect(find.text('Veuillez saisir votre mot de passe.'), findsOneWidget);
    expect(harness.repository.loginCalls, 0);
  });

  testWidgets('toggles the password visibility', (WidgetTester tester) async {
    await pumpAuthApp(tester);

    EditableText editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('login_password_field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('login_password_field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.obscureText, isFalse);
  });

  testWidgets('remember me is checked by default and passed as true', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(tester);

    final AppCheckboxTile checkbox = tester.widget<AppCheckboxTile>(
      find.byKey(const Key('login_remember')),
    );
    expect(checkbox.value, isTrue);

    await fillLogin(tester);
    await submitLogin(tester);

    expect(harness.repository.loginCalls, 1);
    expect(harness.session.signedInCalls, 1);
    expect(harness.session.remember, isTrue);
    expect(harness.session.tokens?.accessToken, 'access');
  });

  testWidgets('unchecking remember me is passed as false', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(tester);

    await tester.tap(find.byKey(const Key('login_remember')));
    await tester.pumpAndSettle();
    await fillLogin(tester);
    await submitLogin(tester);

    expect(harness.session.signedInCalls, 1);
    expect(harness.session.remember, isFalse);
  });

  testWidgets('loading disables the submit button', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    repository.loginCompleter = Completer<AuthSession>();
    final AuthHarness harness = await pumpAuthApp(
      tester,
      repository: repository,
    );

    await fillLogin(tester);
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();

    final AppButton button = tester.widget<AppButton>(
      find.byKey(const Key('login_submit')),
    );
    expect(button.loading, isTrue);
    expect(button.onPressed, isNull);

    repository.loginCompleter!.complete(buildSession());
    await tester.pumpAndSettle();

    expect(harness.session.signedInCalls, 1);
  });

  testWidgets('a login error shows the banner and keeps the fields', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    repository.loginError = const ApiException(
      code: 'UNAUTHORIZED',
      message: 'Identifiants incorrects.',
      statusCode: 401,
    );
    await pumpAuthApp(tester, repository: repository);

    await fillLogin(tester);
    await submitLogin(tester);

    expect(find.byType(AppErrorBanner), findsOneWidget);
    expect(
      find.text('Numéro de téléphone ou mot de passe incorrect.'),
      findsOneWidget,
    );
    expect(fieldText(tester, 'login_phone_field'), '90 20 30 40');
    expect(fieldText(tester, 'login_password_field'), 'secret123');
  });

  testWidgets('the forgot password link opens its route', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(tester);

    await tester.tap(find.byKey(const Key('login_forgot')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/forgot-password');
  });

  testWidgets('the create account link opens its route', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(tester);

    await tester.tap(find.byKey(const Key('login_register')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/register');
  });

  testWidgets(
    'offers a phone verification path when the number is unverified',
    (WidgetTester tester) async {
      final FakeAuthRepository repository = FakeAuthRepository()
        ..loginError = const ApiException(
          code: 'UNAUTHORIZED',
          message: 'Numéro de téléphone non vérifié.',
          statusCode: 401,
        );
      final AuthHarness harness = await pumpAuthApp(
        tester,
        repository: repository,
      );

      await fillLogin(tester);
      await submitLogin(tester);

      expect(find.byKey(const Key('login_verify_phone')), findsOneWidget);

      await tester.tap(find.byKey(const Key('login_verify_phone')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(harness.repository.requestOtpCalls, 1);
      expect(harness.repository.lastPurpose, AuthPurpose.verifyPhone);
      expect(harness.router.state.uri.path, '/otp');
      final OtpArgs args = harness.router.state.extra! as OtpArgs;
      expect(args.phone, '+22790203040');
      expect(args.purpose, AuthPurpose.verifyPhone);
    },
  );

  testWidgets('requires a valid phone before requesting a login code', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(tester);

    await tester.enterText(fieldByKey('login_phone_field'), '123');
    await tester.tap(find.byKey(const Key('login_sms_code')));
    await tester.pumpAndSettle();

    expect(harness.repository.requestOtpCalls, 0);
    expect(
      find.text('Veuillez saisir un numéro de téléphone valide.'),
      findsOneWidget,
    );

    await tester.enterText(fieldByKey('login_phone_field'), '90203040');
    await tester.tap(find.byKey(const Key('login_sms_code')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(harness.repository.requestOtpCalls, 1);
    expect(harness.repository.lastPurpose, AuthPurpose.login);
    expect(harness.router.state.uri.path, '/otp');
    final OtpArgs args = harness.router.state.extra! as OtpArgs;
    expect(args.purpose, AuthPurpose.login);
  });
}
