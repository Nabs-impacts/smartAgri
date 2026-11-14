import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/design_system/components/gonata_logo.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/features/auth/domain/auth_purpose.dart';
import 'package:smartagri/features/auth/domain/otp_args.dart';

import 'auth_test_harness.dart';

const OtpArgs otpArgs = OtpArgs(
  phone: '+22790203040',
  purpose: AuthPurpose.verifyPhone,
);

void setSmallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> disposeAuthTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  final List<ThemeData> themes = <ThemeData>[AppTheme.light, AppTheme.dark];
  const List<double> keyboardInsets = <double>[0, 280];

  for (final ThemeData theme in themes) {
    for (final double keyboardInset in keyboardInsets) {
      testWidgets(
        'login fits a 320 pt screen with 1.3 text in ${theme.brightness.name} with keyboard $keyboardInset',
        (WidgetTester tester) async {
          setSmallSurface(tester);
          await pumpAuthApp(
            tester,
            initialLocation: '/login',
            theme: theme,
            textScale: 1.3,
            keyboardBottomInset: keyboardInset,
          );

          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('login_submit')), findsOneWidget);
        },
      );

      testWidgets(
        'registration fits a 320 pt screen with 1.3 text in ${theme.brightness.name} with keyboard $keyboardInset',
        (WidgetTester tester) async {
          setSmallSurface(tester);
          await pumpAuthApp(
            tester,
            initialLocation: '/register',
            theme: theme,
            textScale: 1.3,
            keyboardBottomInset: keyboardInset,
          );

          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('register_submit')), findsOneWidget);
        },
      );

      testWidgets(
        'OTP fits a 320 pt screen with 1.3 text in ${theme.brightness.name} with keyboard $keyboardInset',
        (WidgetTester tester) async {
          setSmallSurface(tester);
          await pumpAuthApp(
            tester,
            initialLocation: '/otp',
            initialExtra: otpArgs,
            settle: false,
            theme: theme,
            textScale: 1.3,
            keyboardBottomInset: keyboardInset,
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('otp_submit')), findsOneWidget);
          await disposeAuthTree(tester);
        },
      );

      testWidgets(
        'forgot password fits a 320 pt screen with 1.3 text in ${theme.brightness.name} with keyboard $keyboardInset',
        (WidgetTester tester) async {
          setSmallSurface(tester);
          await pumpAuthApp(
            tester,
            initialLocation: '/forgot-password',
            theme: theme,
            textScale: 1.3,
            keyboardBottomInset: keyboardInset,
          );

          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('forgot_send_code')), findsOneWidget);
        },
      );
    }
  }

  testWidgets('the full logo shrinks when the keyboard opens', (
    WidgetTester tester,
  ) async {
    await pumpAuthApp(tester, initialLocation: '/login');
    SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, 196);

    await pumpAuthApp(
      tester,
      initialLocation: '/login',
      keyboardBottomInset: 280,
    );
    svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, lessThan(196));
    await disposeAuthTree(tester);
  });

  testWidgets('the symbol logo shrinks when the keyboard opens', (
    WidgetTester tester,
  ) async {
    await pumpAuthApp(
      tester,
      initialLocation: '/otp',
      initialExtra: otpArgs,
      settle: false,
    );
    await tester.pump();
    SvgPicture svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, 72);

    await pumpAuthApp(
      tester,
      initialLocation: '/otp',
      initialExtra: otpArgs,
      settle: false,
      keyboardBottomInset: 280,
    );
    await tester.pump();
    svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.width, lessThan(72));
    await disposeAuthTree(tester);
  });

  testWidgets('the authentication screens use the full or symbol logo', (
    WidgetTester tester,
  ) async {
    await pumpAuthApp(tester, initialLocation: '/login');
    expect(find.byType(GonataLogo), findsOneWidget);

    await pumpAuthApp(
      tester,
      initialLocation: '/otp',
      initialExtra: otpArgs,
      settle: false,
    );
    await tester.pump();
    expect(find.byType(GonataLogo), findsOneWidget);
    await disposeAuthTree(tester);
  });
}
