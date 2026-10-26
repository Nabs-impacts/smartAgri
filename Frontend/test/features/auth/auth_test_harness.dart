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
import 'package:smartagri/features/auth/domain/otp_args.dart';
import 'package:smartagri/features/auth/domain/user_profile.dart';
import 'package:smartagri/features/auth/presentation/forgot_password_page.dart';
import 'package:smartagri/features/auth/presentation/login_page.dart';
import 'package:smartagri/features/auth/presentation/otp_page.dart';
import 'package:smartagri/features/auth/presentation/register_page.dart';
import 'package:smartagri/features/common/placeholder_page.dart';
import 'package:smartagri/features/legal/legal_page.dart';

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
  ApiException? registerError;
  Completer<void>? registerCompleter;
  ApiException? requestOtpError;
  ApiException? verifyOtpError;
  ApiException? resetPasswordError;
  ApiException? acceptConsentsError;
  int loginCalls = 0;
  int registerCalls = 0;
  int requestOtpCalls = 0;
  int verifyOtpCalls = 0;
  int resetPasswordCalls = 0;
  int acceptConsentsCalls = 0;
  String? lastPhone;
  String? lastPassword;
  String? lastFullName;
  String? lastLanguage;
  AuthPurpose? lastPurpose;
  AuthPurpose? lastVerifyPurpose;
  String? lastCode;
  String? lastNewPassword;
  List<ConsentChoice> lastConsents = <ConsentChoice>[];

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
  Future<String> register({
    required String phone,
    required String fullName,
    String language = 'fr',
    String? password,
  }) async {
    registerCalls++;
    lastPhone = phone;
    lastFullName = fullName;
    lastLanguage = language;
    lastPassword = password;
    if (registerError != null) {
      throw registerError!;
    }
    if (registerCompleter != null) {
      await registerCompleter!.future;
    }
    return 'Compte créé.';
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
  Future<AuthSession> verifyOtp({
    required String phone,
    required String code,
    required AuthPurpose purpose,
  }) async {
    verifyOtpCalls++;
    lastPhone = phone;
    lastCode = code;
    lastVerifyPurpose = purpose;
    if (verifyOtpError != null) {
      throw verifyOtpError!;
    }
    return session;
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
    lastConsents = choices;
    if (acceptConsentsError != null) {
      throw acceptConsentsError!;
    }
  }
}

class RecordingSessionController extends SessionController {
  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  final ValueNotifier<bool> authenticated = ValueNotifier<bool>(false);
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
    authenticated.value = true;
    changes.value++;
  }

  @override
  Future<void> signedOut() async {
    signedOutCalls++;
    state = SessionState.unauthenticated;
    authenticated.value = false;
    changes.value++;
  }
}

class AuthHarness {
  AuthHarness(this.repository, this.session, this.router, this.container);

  final FakeAuthRepository repository;
  final RecordingSessionController session;
  final GoRouter router;
  final ProviderContainer container;
}

Future<AuthHarness> pumpAuthApp(
  WidgetTester tester, {
  String initialLocation = '/login',
  Object? initialExtra,
  FakeAuthRepository? repository,
  RecordingSessionController? session,
  bool settle = true,
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
    initialExtra: initialExtra,
    refreshListenable: controller.changes,
    redirect: (_, GoRouterState state) {
      final String path = state.uri.path;
      if (controller.authenticated.value &&
          (path == '/login' || path == '/otp' || path == '/register')) {
        return '/home';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: '/otp',
        redirect: (_, GoRouterState state) =>
            state.extra is OtpArgs ? null : '/login',
        builder: (_, GoRouterState state) =>
            OtpPage(args: state.extra! as OtpArgs),
      ),
      GoRoute(
        path: '/legal/terms',
        builder: (_, _) => const LegalPage(document: LegalDocument.terms),
      ),
      GoRoute(
        path: '/legal/privacy',
        builder: (_, _) => const LegalPage(document: LegalDocument.privacy),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const PlaceholderPage(title: 'Accueil'),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return AuthHarness(repo, controller, router, container);
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
