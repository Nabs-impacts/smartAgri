import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/core/session/session_controller.dart';
import 'package:smartagri/core/session/session_state.dart';
import 'package:smartagri/core/storage/token_store.dart';
import 'package:smartagri/design_system/theme.dart';
import 'package:smartagri/features/auth/data/auth_repository.dart';
import 'package:smartagri/features/auth/domain/auth_purpose.dart';
import 'package:smartagri/features/auth/domain/auth_session.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';
import 'package:smartagri/features/auth/domain/user_profile.dart';
import 'package:smartagri/features/auth/presentation/forgot_password_page.dart';
import 'package:smartagri/features/auth/presentation/login_page.dart';
import 'package:smartagri/features/common/placeholder_page.dart';

import '../../core/storage/fake_token_storage.dart';

AuthSession buildSession() {
  return AuthSession(
    tokens: AuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ),
    tokenType: 'bearer',
    user: const UserProfile(
      id: 'id',
      phone: '+22790203040',
      fullName: 'Amina Diallo',
      role: 'farmer',
      language: 'fr',
    ),
  );
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository()
    : super(
        dio: Dio(),
        tokenStore: TokenStore(storage: FakeTokenStorage()),
        onSignedOut: () async {},
      );

  AuthSession session = buildSession();
  ApiException? loginError;
  Completer<AuthSession>? loginCompleter;
  ApiException? requestOtpError;
  ApiException? resetPasswordError;
  int loginCalls = 0;
  int requestOtpCalls = 0;
  int resetPasswordCalls = 0;
  int acceptConsentsCalls = 0;
  String? lastPhone;
  String? lastPassword;
  AuthPurpose? lastPurpose;
  String? lastCode;
  String? lastNewPassword;

  @override
  Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    loginCalls++;
    lastPhone = phone;
    lastPassword = password;
    if (loginError != null) {
      throw loginError!;
    }
    if (loginCompleter != null) {
      return loginCompleter!.future;
    }
    return session;
  }

  @override
  Future<void> requestOtp({
    required String phone,
    required AuthPurpose purpose,
  }) async {
    requestOtpCalls++;
    lastPhone = phone;
    lastPurpose = purpose;
    if (requestOtpError != null) {
      throw requestOtpError!;
    }
  }

  @override
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    resetPasswordCalls++;
    lastPhone = phone;
    lastCode = code;
    lastNewPassword = newPassword;
    if (resetPasswordError != null) {
      throw resetPasswordError!;
    }
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> acceptConsents(List<ConsentChoice> choices) async {
    acceptConsentsCalls++;
  }
}

class RecordingSessionController extends SessionController {
  AuthTokens? tokens;
  bool? remember;
  int signedInCalls = 0;
  int signedOutCalls = 0;

  @override
  SessionState build() => SessionState.unauthenticated;

  @override
  Future<void> signedIn(AuthTokens tokens, bool remember) async {
    signedInCalls++;
    this.tokens = tokens;
    this.remember = remember;
    state = SessionState.authenticated;
  }

  @override
  Future<void> signedOut() async {
    signedOutCalls++;
    state = SessionState.unauthenticated;
  }
}

class AuthHarness {
  AuthHarness(this.repository, this.session, this.router);

  final FakeAuthRepository repository;
  final RecordingSessionController session;
  final GoRouter router;
}

Future<AuthHarness> pumpAuthApp(
  WidgetTester tester, {
  String initialLocation = '/login',
  FakeAuthRepository? repository,
  RecordingSessionController? session,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final FakeAuthRepository repo = repository ?? FakeAuthRepository();
  final RecordingSessionController controller =
      session ?? RecordingSessionController();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      authRepositoryProvider.overrideWithValue(repo),
      sessionControllerProvider.overrideWith(() => controller),
    ],
  );
  addTearDown(container.dispose);
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const PlaceholderPage(title: 'Inscription'),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return AuthHarness(repo, controller, router);
}

Finder fieldByKey(String key) {
  return find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextFormField),
  );
}

String fieldText(WidgetTester tester, String key) {
  return tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;
}
