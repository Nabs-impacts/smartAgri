import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/network/auth_interceptor.dart';
import 'package:smartagri/core/session/session_events.dart';
import 'package:smartagri/core/storage/token_store.dart';

import '../storage/fake_token_storage.dart';
import 'fake_http_adapter.dart';

const String baseUrl = 'http://test.local';

Dio buildDio(FakeHttpAdapter adapter) {
  return Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = adapter;
}

void main() {
  test('refreshes once and retries every concurrent request', () async {
    final FakeTokenStorage storage = FakeTokenStorage();
    final TokenStore store = TokenStore(storage: storage);
    await store.save('old-access', 'old-refresh', 3600, remember: true);
    final SessionEvents events = SessionEvents();
    addTearDown(events.dispose);
    int refreshCalls = 0;

    final FakeHttpAdapter adapter = FakeHttpAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/auth/refresh') {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return jsonResponse(200, <String, dynamic>{
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
          'expires_in': 3600,
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (options.headers['Authorization'] == 'Bearer new-access') {
        return jsonResponse(200, <String, dynamic>{'ok': true});
      }
      return errorResponse(401, 'UNAUTHORIZED', 'Jeton expiré.');
    });

    final Dio refreshDio = buildDio(adapter);
    final Dio api = buildDio(adapter);
    api.interceptors.add(
      AuthInterceptor(
        dio: api,
        refreshDio: refreshDio,
        tokenStore: store,
        events: events,
      ),
    );

    final List<Response<dynamic>> responses = await Future.wait(
      <Future<Response<dynamic>>>[
        api.get<dynamic>('/items'),
        api.get<dynamic>('/items'),
        api.get<dynamic>('/items'),
      ],
    );

    expect(responses, hasLength(3));
    expect(refreshCalls, 1);
    final List<RequestSnapshot> itemRequests = adapter.requests
        .where((RequestSnapshot request) => request.path == '/items')
        .toList();
    expect(itemRequests, hasLength(6));
    expect(
      itemRequests
          .where(
            (RequestSnapshot request) =>
                request.authorization == 'Bearer old-access',
          )
          .length,
      3,
    );
    expect(
      itemRequests
          .where(
            (RequestSnapshot request) =>
                request.authorization == 'Bearer new-access',
          )
          .length,
      3,
    );
    final AuthTokens? tokens = await store.read();
    expect(tokens!.accessToken, 'new-access');
    expect(tokens.refreshToken, 'new-refresh');
  });

  test('clears tokens and emits sessionExpired on refresh 401', () async {
    final FakeTokenStorage storage = FakeTokenStorage();
    final TokenStore store = TokenStore(storage: storage);
    await store.save('old-access', 'old-refresh', 3600, remember: true);
    final SessionEvents events = SessionEvents();
    addTearDown(events.dispose);
    final Future<void> expired = events.sessionExpired.first;

    final FakeHttpAdapter adapter = FakeHttpAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/auth/refresh') {
        return errorResponse(401, 'UNAUTHORIZED', 'Jeton expiré.');
      }
      return errorResponse(401, 'UNAUTHORIZED', 'Jeton expiré.');
    });
    final Dio refreshDio = buildDio(adapter);
    final Dio api = buildDio(adapter);
    api.interceptors.add(
      AuthInterceptor(
        dio: api,
        refreshDio: refreshDio,
        tokenStore: store,
        events: events,
      ),
    );

    await expectLater(api.get<dynamic>('/items'), throwsA(isA<DioException>()));
    await expired.timeout(const Duration(seconds: 1));
    expect(await store.read(), isNull);
    expect(storage.values, isEmpty);
  });

  test('keeps tokens when the refresh fails on the network', () async {
    final FakeTokenStorage storage = FakeTokenStorage();
    final TokenStore store = TokenStore(storage: storage);
    await store.save('old-access', 'old-refresh', 3600, remember: true);
    final SessionEvents events = SessionEvents();
    addTearDown(events.dispose);

    final FakeHttpAdapter adapter = FakeHttpAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/auth/refresh') {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      return errorResponse(401, 'UNAUTHORIZED', 'Jeton expiré.');
    });
    final Dio refreshDio = buildDio(adapter);
    final Dio api = buildDio(adapter);
    api.interceptors.add(
      AuthInterceptor(
        dio: api,
        refreshDio: refreshDio,
        tokenStore: store,
        events: events,
      ),
    );

    await expectLater(api.get<dynamic>('/items'), throwsA(isA<DioException>()));
    final AuthTokens? tokens = await store.read();
    expect(tokens, isNotNull);
    expect(tokens!.accessToken, 'old-access');
    expect(tokens.refreshToken, 'old-refresh');
  });

  test('never injects or refreshes tokens on auth routes', () async {
    final FakeTokenStorage storage = FakeTokenStorage();
    final TokenStore store = TokenStore(storage: storage);
    await store.save('old-access', 'old-refresh', 3600, remember: true);
    final SessionEvents events = SessionEvents();
    addTearDown(events.dispose);
    int refreshCalls = 0;

    final FakeHttpAdapter adapter = FakeHttpAdapter((
      RequestOptions options,
    ) async {
      if (options.path == '/auth/refresh') {
        refreshCalls++;
      }
      return errorResponse(401, 'UNAUTHORIZED', 'Identifiants invalides.');
    });
    final Dio refreshDio = buildDio(adapter);
    final Dio api = buildDio(adapter);
    api.interceptors.add(
      AuthInterceptor(
        dio: api,
        refreshDio: refreshDio,
        tokenStore: store,
        events: events,
      ),
    );

    await expectLater(
      api.post<dynamic>('/auth/login', data: <String, dynamic>{}),
      throwsA(isA<DioException>()),
    );
    expect(refreshCalls, 0);
    expect(adapter.requests.single.authorization, isNull);
  });
}
