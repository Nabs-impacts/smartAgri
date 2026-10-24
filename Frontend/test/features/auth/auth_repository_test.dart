import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/core/storage/token_store.dart';
import 'package:smartagri/features/auth/data/auth_repository.dart';
import 'package:smartagri/features/auth/domain/auth_purpose.dart';
import 'package:smartagri/features/auth/domain/auth_session.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';

import '../../core/network/fake_http_adapter.dart';
import '../../core/storage/fake_token_storage.dart';

const String baseUrl = 'http://test.local';

Map<String, dynamic> tokenBody() {
  return <String, dynamic>{
    'access_token': 'access',
    'refresh_token': 'refresh',
    'token_type': 'bearer',
    'expires_in': 1800,
    'user': <String, dynamic>{
      'id': 'id',
      'phone': '+22790203040',
      'full_name': 'Amina Diallo',
      'email': null,
      'language': 'fr',
      'role': 'farmer',
    },
  };
}

class Harness {
  final TokenStore store = TokenStore(storage: FakeTokenStorage());
  FakeHttpAdapter adapter = FakeHttpAdapter(
    (RequestOptions options) async => jsonResponse(200, <String, dynamic>{}),
  );
  bool signedOut = false;

  AuthRepository build() {
    final Dio dio = Dio(BaseOptions(baseUrl: baseUrl))
      ..httpClientAdapter = adapter;
    return AuthRepository(
      dio: dio,
      tokenStore: store,
      onSignedOut: () async {
        signedOut = true;
        await store.clear();
      },
    );
  }
}

void main() {
  test('login sends the normalized body and parses the session', () async {
    final Harness harness = Harness();
    harness.adapter = FakeHttpAdapter(
      (RequestOptions options) async => jsonResponse(200, tokenBody()),
    );
    final AuthRepository repository = harness.build();

    final AuthSession session = await repository.login(
      phone: '90 20 30 40',
      password: 'secret123',
    );

    expect(harness.adapter.requests.single.path, '/auth/login');
    expect(harness.adapter.requests.single.data, <String, dynamic>{
      'phone': '+22790203040',
      'password': 'secret123',
    });
    expect(session.tokens.accessToken, 'access');
    expect(session.user.fullName, 'Amina Diallo');
  });

  test('register sends the normalized body', () async {
    final Harness harness = Harness();
    harness.adapter = FakeHttpAdapter(
      (RequestOptions options) async => jsonResponse(201, <String, dynamic>{
        'message': 'Compte créé.',
        'phone': '+22790203040',
      }),
    );
    final AuthRepository repository = harness.build();

    final String message = await repository.register(
      phone: '0022790203040',
      fullName: 'Amina Diallo',
      language: 'ha',
    );

    expect(message, 'Compte créé.');
    expect(harness.adapter.requests.single.path, '/auth/register');
    expect(harness.adapter.requests.single.data, <String, dynamic>{
      'phone': '+22790203040',
      'full_name': 'Amina Diallo',
      'language': 'ha',
    });
  });

  test('register includes the password when provided', () async {
    final Harness harness = Harness();
    harness.adapter = FakeHttpAdapter(
      (RequestOptions options) async => jsonResponse(201, <String, dynamic>{
        'message': 'Compte créé.',
        'phone': '+22790203040',
      }),
    );
    final AuthRepository repository = harness.build();

    await repository.register(
      phone: '+22790203040',
      fullName: 'Amina Diallo',
      language: 'fr',
      password: 'secret123',
    );

    expect(harness.adapter.requests.single.data, <String, dynamic>{
      'phone': '+22790203040',
      'full_name': 'Amina Diallo',
      'language': 'fr',
      'password': 'secret123',
    });
  });

  test('requestOtp sends the purpose', () async {
    final Harness harness = Harness();
    harness.adapter = FakeHttpAdapter(
      (RequestOptions options) async =>
          jsonResponse(202, <String, dynamic>{'message': 'ok'}),
    );
    final AuthRepository repository = harness.build();

    await repository.requestOtp(
      phone: '22790203040',
      purpose: AuthPurpose.resetPassword,
    );

    expect(harness.adapter.requests.single.path, '/auth/otp/request');
    expect(harness.adapter.requests.single.data, <String, dynamic>{
      'phone': '+22790203040',
      'purpose': 'reset_password',
    });
  });

  test('verifyOtp sends the code and returns a session', () async {
    final Harness harness = Harness();
    harness.adapter = FakeHttpAdapter(
      (RequestOptions options) async => jsonResponse(200, tokenBody()),
    );
    final AuthRepository repository = harness.build();

    await repository.verifyOtp(
      phone: '90203040',
      code: '123456',
      purpose: AuthPurpose.login,
    );

    expect(harness.adapter.requests.single.path, '/auth/otp/verify');
    expect(harness.adapter.requests.single.data, <String, dynamic>{
      'phone': '+22790203040',
      'code': '123456',
      'purpose': 'login',
    });
  });

  test('resetPassword sends the new password', () async {
    final Harness harness = Harness();
    harness.adapter = FakeHttpAdapter(
      (RequestOptions options) async =>
          jsonResponse(200, <String, dynamic>{'message': 'ok'}),
    );
    final AuthRepository repository = harness.build();

    await repository.resetPassword(
      phone: '90203040',
      code: '123456',
      newPassword: 'nouveau123',
    );

    expect(harness.adapter.requests.single.path, '/auth/password/reset');
    expect(harness.adapter.requests.single.data, <String, dynamic>{
      'phone': '+22790203040',
      'code': '123456',
      'new_password': 'nouveau123',
    });
  });

  test('an invalid phone is rejected without a network call', () async {
    final Harness harness = Harness();
    final AuthRepository repository = harness.build();

    await expectLater(
      repository.requestOtp(phone: '123', purpose: AuthPurpose.login),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.code,
          'code',
          'INVALID_PHONE',
        ),
      ),
    );
    expect(harness.adapter.requests, isEmpty);
  });

  test('logout reads the current refresh token and signs out', () async {
    final Harness harness = Harness();
    await harness.store.save('access-a', 'refresh-a', 3600, remember: true);
    await harness.store.save('access-b', 'refresh-b', 3600, remember: true);
    harness.adapter = FakeHttpAdapter(
      (RequestOptions options) async =>
          jsonResponse(200, <String, dynamic>{'message': 'ok'}),
    );
    final AuthRepository repository = harness.build();

    await repository.logout();

    expect(harness.adapter.requests.single.path, '/auth/logout');
    expect(harness.adapter.requests.single.data, <String, dynamic>{
      'refresh_token': 'refresh-b',
    });
    expect(harness.signedOut, isTrue);
    expect(await harness.store.read(), isNull);
  });

  test('logout clears the session even when the network fails', () async {
    final Harness harness = Harness();
    await harness.store.save('access', 'refresh', 3600, remember: true);
    harness.adapter = FakeHttpAdapter((RequestOptions options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final AuthRepository repository = harness.build();

    await repository.logout();

    expect(harness.signedOut, isTrue);
    expect(await harness.store.read(), isNull);
  });

  test('acceptConsents sends one call per choice', () async {
    final Harness harness = Harness();
    harness.adapter = FakeHttpAdapter(
      (RequestOptions options) async => jsonResponse(201, <String, dynamic>{
        'id': 'id',
        'type': 'terms',
        'version': '1.0',
        'accepted': true,
      }),
    );
    final AuthRepository repository = harness.build();

    await repository.acceptConsents(const <ConsentChoice>[
      ConsentChoice(type: ConsentType.terms, accepted: true),
      ConsentChoice(type: ConsentType.research, accepted: false),
    ]);

    expect(harness.adapter.requests, hasLength(2));
    expect(harness.adapter.requests.first.data, <String, dynamic>{
      'type': 'terms',
      'version': '1.0',
      'accepted': true,
    });
    expect(harness.adapter.requests.last.data, <String, dynamic>{
      'type': 'research',
      'version': '1.0',
      'accepted': false,
    });
  });
}
