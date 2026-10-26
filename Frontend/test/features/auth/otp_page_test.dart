import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/design_system/components/app_button.dart';
import 'package:smartagri/design_system/components/app_error_banner.dart';
import 'package:smartagri/design_system/components/app_text_button.dart';
import 'package:smartagri/features/auth/data/pending_consents_store.dart';
import 'package:smartagri/features/auth/domain/auth_purpose.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';
import 'package:smartagri/features/auth/domain/otp_args.dart';
import 'package:smartagri/features/auth/presentation/login_page.dart';
import 'package:smartagri/features/auth/presentation/otp_page.dart';

import 'auth_test_harness.dart';

const OtpArgs verifyArgs = OtpArgs(
  phone: '+22790203040',
  purpose: AuthPurpose.verifyPhone,
);

const List<ConsentChoice> choices = <ConsentChoice>[
  ConsentChoice(type: ConsentType.terms, accepted: true),
  ConsentChoice(type: ConsentType.privacy, accepted: true),
];

Future<void> enterOtp(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const Key('otp_digit_0')), code);
  await tester.pump();
}

String digitText(WidgetTester tester, int index) {
  return tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(Key('otp_digit_$index')),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;
}

Future<void> waitForCountdown(WidgetTester tester) async {
  for (int index = 0; index < 60; index++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('redirects to login without arguments', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/otp',
    );

    expect(harness.router.state.uri.path, '/login');
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(OtpPage), findsNothing);
  });

  testWidgets('masks the phone number', (WidgetTester tester) async {
    await pumpAuthApp(
      tester,
      initialLocation: '/otp',
      initialExtra: verifyArgs,
      settle: false,
    );

    expect(find.textContaining('+227 •• •• 30 40'), findsOneWidget);
    expect(find.textContaining('+22790203040'), findsNothing);
  });

  testWidgets('enables the validate button at six digits', (
    WidgetTester tester,
  ) async {
    await pumpAuthApp(
      tester,
      initialLocation: '/otp',
      initialExtra: verifyArgs,
      settle: false,
    );

    AppButton button = tester.widget<AppButton>(
      find.byKey(const Key('otp_submit')),
    );
    expect(button.onPressed, isNull);

    await enterOtp(tester, '123456');

    button = tester.widget<AppButton>(find.byKey(const Key('otp_submit')));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('signs in, sends pending consents once and redirects', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/otp',
      initialExtra: verifyArgs,
      settle: false,
    );
    await harness.container.read(pendingConsentsStoreProvider).add(choices);
    await enterOtp(tester, '123456');

    await tester.tap(find.byKey(const Key('otp_submit')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(harness.session.signedInCalls, 1);
    expect(harness.session.remember, isTrue);
    expect(harness.router.state.uri.path, '/home');
    expect(harness.repository.acceptConsentsCalls, 1);
    expect(
      harness.container.read(pendingConsentsStoreProvider).read(),
      isEmpty,
    );
  });

  testWidgets('clears the boxes and shows an invalid code error', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository()
      ..verifyOtpError = const ApiException(
        code: 'UNAUTHORIZED',
        message: 'Code invalide ou expiré.',
        statusCode: 401,
      );
    await pumpAuthApp(
      tester,
      initialLocation: '/otp',
      initialExtra: verifyArgs,
      repository: repository,
      settle: false,
    );
    await enterOtp(tester, '123456');

    await tester.tap(find.byKey(const Key('otp_submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppErrorBanner), findsOneWidget);
    expect(
      find.text('Le code de vérification est invalide ou expiré.'),
      findsOneWidget,
    );
    for (int index = 0; index < 6; index++) {
      expect(digitText(tester, index), isEmpty);
    }
  });

  testWidgets('resends the code only after the countdown', (
    WidgetTester tester,
  ) async {
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/otp',
      initialExtra: verifyArgs,
      settle: false,
    );

    expect(find.text('Renvoyer le code (60 s)'), findsOneWidget);
    expect(
      tester
          .widget<AppTextButton>(find.byKey(const Key('otp_resend')))
          .onPressed,
      isNull,
    );

    await waitForCountdown(tester);
    expect(
      tester
          .widget<AppTextButton>(find.byKey(const Key('otp_resend')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('otp_resend')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.repository.requestOtpCalls, 1);
    expect(harness.repository.lastPurpose, AuthPurpose.verifyPhone);
    expect(find.text('Renvoyer le code (60 s)'), findsOneWidget);
  });

  testWidgets('shows a clear rate limit message on resend', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository()
      ..requestOtpError = const ApiException(
        code: 'RATE_LIMITED',
        message: 'Trop de demandes de code, veuillez patienter.',
        statusCode: 429,
      );
    await pumpAuthApp(
      tester,
      initialLocation: '/otp',
      initialExtra: verifyArgs,
      repository: repository,
      settle: false,
    );

    await waitForCountdown(tester);
    await tester.tap(find.byKey(const Key('otp_resend')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppErrorBanner), findsOneWidget);
    expect(
      find.text('Trop de tentatives. Veuillez patienter avant de réessayer.'),
      findsOneWidget,
    );
  });

  testWidgets('the back button returns to login', (WidgetTester tester) async {
    final AuthHarness harness = await pumpAuthApp(
      tester,
      initialLocation: '/otp',
      initialExtra: verifyArgs,
      settle: false,
    );

    await tester.tap(find.byKey(const Key('otp_back')));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/login');
  });
}
