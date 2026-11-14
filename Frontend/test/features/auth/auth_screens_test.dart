import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/app_button.dart';
import 'package:smartagri/design_system/components/gonata_logo.dart';
import 'package:smartagri/features/auth/domain/auth_purpose.dart';
import 'package:smartagri/features/auth/domain/otp_args.dart';

import 'auth_test_harness.dart';

const OtpArgs otpArgs = OtpArgs(
  phone: '+22790203040',
  purpose: AuthPurpose.verifyPhone,
);

void expectLanguageSwitcher() {
  expect(find.byKey(const ValueKey<String>('language_fr')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('language_ha')), findsOneWidget);
  expect(find.byKey(const ValueKey<String>('language_dje')), findsOneWidget);
  expect(find.text('FR'), findsOneWidget);
  expect(find.text('HA'), findsOneWidget);
  expect(find.text('ZA'), findsOneWidget);
}

void expectNoEmailMention() {
  expect(
    find.textContaining(RegExp('e-?mail', caseSensitive: false)),
    findsNothing,
  );
}

void main() {
  testWidgets('the login screen presents its elements without any email', (
    WidgetTester tester,
  ) async {
    await pumpAuthApp(tester);

    expect(find.byType(GonataLogo), findsOneWidget);
    expect(find.byKey(const Key('login_phone_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.byKey(const Key('login_remember')), findsOneWidget);
    expect(find.byKey(const Key('login_forgot')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.byKey(const Key('login_register')), findsOneWidget);
    expect(find.text('Pas encore de compte ?'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expectLanguageSwitcher();
    expectNoEmailMention();
  });

  testWidgets('the registration screen presents its elements and rules', (
    WidgetTester tester,
  ) async {
    await pumpAuthApp(tester, initialLocation: '/register');

    expect(find.byType(GonataLogo), findsOneWidget);
    expect(find.byKey(const Key('register_last_name_field')), findsOneWidget);
    expect(find.byKey(const Key('register_first_name_field')), findsOneWidget);
    expect(find.byKey(const Key('register_phone_field')), findsOneWidget);
    expect(find.byKey(const Key('register_password_field')), findsOneWidget);
    expect(find.byKey(const Key('register_confirm_field')), findsOneWidget);
    expect(find.text('Au moins 8 caractères et au plus 128.'), findsOneWidget);
    expect(find.byKey(const Key('register_consent_terms')), findsOneWidget);
    expect(find.byKey(const Key('register_consent_privacy')), findsOneWidget);
    expect(find.byKey(const Key('register_read_terms')), findsOneWidget);
    expect(find.byKey(const Key('register_read_privacy')), findsOneWidget);
    expect(find.byKey(const Key('register_consent_data')), findsOneWidget);
    expect(find.byKey(const Key('register_consent_research')), findsOneWidget);
    expect(find.byKey(const Key('register_submit')), findsOneWidget);
    expect(find.byKey(const Key('register_login_link')), findsOneWidget);
    expect(find.text('Déjà un compte ?'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expectLanguageSwitcher();
    expectNoEmailMention();
  });

  testWidgets('the OTP screen presents the symbol and the masked phone', (
    WidgetTester tester,
  ) async {
    await pumpAuthApp(
      tester,
      initialLocation: '/otp',
      initialExtra: otpArgs,
      settle: false,
    );
    await tester.pump();

    expect(find.byType(GonataLogo), findsOneWidget);
    expect(find.textContaining('+227 •• •• 30 40'), findsOneWidget);
    expect(find.byKey(const Key('otp_digit_0')), findsOneWidget);
    expect(find.byKey(const Key('otp_submit')), findsOneWidget);
    expect(find.byKey(const Key('otp_back')), findsOneWidget);
    expect(find.text('Corriger le numéro'), findsOneWidget);
    final AppButton submit = tester.widget<AppButton>(
      find.byKey(const Key('otp_submit')),
    );
    expect(submit.onPressed, isNull);
    expectLanguageSwitcher();
    expectNoEmailMention();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the forgot password screen presents its elements and rules', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/forgot-password',
    );

    expect(find.byType(GonataLogo), findsOneWidget);
    expect(find.byKey(const Key('forgot_phone_field')), findsOneWidget);
    expect(find.byKey(const Key('forgot_send_code')), findsOneWidget);
    expect(find.byKey(const Key('forgot_back')), findsOneWidget);
    expectLanguageSwitcher();
    expectNoEmailMention();

    await tester.enterText(fieldByKey('forgot_phone_field'), '90203040');
    await tester.tap(find.byKey(const Key('forgot_send_code')));
    await tester.pumpAndSettle();

    expect(harness.repository.requestOtpCalls, 1);
    expect(find.byKey(const Key('forgot_code_field')), findsOneWidget);
    expect(find.byKey(const Key('forgot_password_field')), findsOneWidget);
    expect(find.byKey(const Key('forgot_confirmation_field')), findsOneWidget);
    expect(find.text('Au moins 8 caractères et au plus 128.'), findsOneWidget);
    expect(find.byKey(const Key('forgot_change_password')), findsOneWidget);
    expect(find.byKey(const Key('forgot_resend')), findsOneWidget);
    expectLanguageSwitcher();
    expectNoEmailMention();
  });
}
