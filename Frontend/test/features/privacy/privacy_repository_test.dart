import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/core/storage/token_store.dart';
import 'package:smartagri/features/auth/data/pending_consents_store.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';
import 'package:smartagri/features/privacy/data/privacy_repository.dart';
import 'package:smartagri/features/profile/data/me_cache.dart';

import '../../core/network/recording_adapter.dart';
import '../../core/storage/fake_token_storage.dart';

class Harness {
  Harness({
    required this.repository,
    required this.preferences,
    required this.tokenStorage,
    required this.pending,
    required this.signedOut,
  });

  final PrivacyRepository repository;
  final SharedPreferences preferences;
  final FakeTokenStorage tokenStorage;
  final PendingConsentsStore pending;
  final List<int> signedOut;
}

Future<Harness> buildHarness(RecordingAdapter adapter) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    LanguageController.storageKey: 'ha',
    MeCache.storageKey: 'cache',
    'personal_cache': 'value',
  });
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final FakeTokenStorage tokenStorage = FakeTokenStorage();
  final TokenStore tokenStore = TokenStore(storage: tokenStorage);
  await tokenStore.save('access', 'refresh', 3600, remember: true);
  final MeCache meCache = MeCache(preferences: preferences);
  final PendingConsentsStore pending = PendingConsentsStore(
    preferences: preferences,
  );
  await pending.set('90203040', const <ConsentChoice>[
    ConsentChoice(type: ConsentType.terms, accepted: true),
  ]);
  final List<int> signedOut = <int>[];
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
  dio.httpClientAdapter = adapter;
  final PrivacyRepository repository = PrivacyRepository(
    dio: dio,
    tokenStore: tokenStore,
    meCache: meCache,
    pendingConsentsStore: pending,
    preferences: preferences,
    onSignedOut: () async => signedOut.add(1),
    now: () => DateTime(2026, 11, 4),
  );
  return Harness(
    repository: repository,
    preferences: preferences,
    tokenStorage: tokenStorage,
    pending: pending,
    signedOut: signedOut,
  );
}

void main() {
  test('exports the JSON bytes with a dated file name', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, <String, dynamic>{
            'user': <String, dynamic>{'id': 'u1'},
          }),
    );
    final Harness harness = await buildHarness(adapter);

    final DataExport export = await harness.repository.exportData();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/users/me/export');
    expect(export.fileName, 'smartagri-donnees-2026-11-04.json');
    final Map<String, dynamic> decoded =
        jsonDecode(utf8.decode(export.bytes)) as Map<String, dynamic>;
    expect(decoded['user'], <String, dynamic>{'id': 'u1'});
  });

  test('reads the consents list with the consent date', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, <dynamic>[
            <String, dynamic>{
              'id': '1',
              'type': 'terms',
              'version': '1.0',
              'accepted': true,
              'created_at': '2026-10-01T10:00:00Z',
            },
            <String, dynamic>{
              'id': '2',
              'type': 'research',
              'version': '1.0',
              'accepted': false,
              'date': '2026-10-02T11:00:00Z',
            },
          ]),
    );
    final Harness harness = await buildHarness(adapter);

    final List<ConsentRecord> records = await harness.repository.getConsents();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/users/me/consents');
    expect(records, hasLength(2));
    expect(records[0].type, ConsentType.terms);
    expect(records[0].accepted, isTrue);
    expect(records[0].date, DateTime.parse('2026-10-01T10:00:00Z'));
    expect(records[1].type, ConsentType.research);
    expect(records[1].accepted, isFalse);
    expect(records[1].date, DateTime.parse('2026-10-02T11:00:00Z'));
  });

  test('posts a consent with the application version', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(201, <String, dynamic>{
            'id': '1',
            'type': 'research',
            'version': '1.0',
            'accepted': true,
            'created_at': '2026-11-04T10:00:00Z',
          }),
    );
    final Harness harness = await buildHarness(adapter);

    await harness.repository.setConsent(ConsentType.research, true);

    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/users/me/consents');
    expect(adapter.requests.single.data, <String, dynamic>{
      'type': 'research',
      'version': '1.0',
      'accepted': true,
    });
  });

  test('deletes the account, clears local data and signs out', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, <String, dynamic>{'message': 'Compte supprimé.'}),
    );
    final Harness harness = await buildHarness(adapter);

    await harness.repository.deleteAccount(
      PrivacyRepository.deleteConfirmation,
    );

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/users/me');
    expect(adapter.requests.single.data, <String, dynamic>{
      'confirmation': 'SUPPRIMER MON COMPTE',
    });
    expect(harness.tokenStorage.values, isEmpty);
    expect(await harness.pending.read(), isNull);
    expect(harness.preferences.getString(MeCache.storageKey), isNull);
    expect(harness.preferences.getString('personal_cache'), isNull);
    expect(harness.preferences.getString(LanguageController.storageKey), 'ha');
    expect(harness.signedOut, hasLength(1));
  });

  test('maps the sole owner conflict to a clear message', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async => body(
        409,
        <String, dynamic>{
          'error': <String, dynamic>{'code': 'CONFLICT', 'message': 'Conflit.'},
        },
      ),
    );
    final Harness harness = await buildHarness(adapter);

    await expectLater(
      harness.repository.deleteAccount(PrivacyRepository.deleteConfirmation),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException error) => error.code,
              'code',
              PrivacyRepository.ownerConflictCode,
            )
            .having(
              (ApiException error) => error.message,
              'message',
              PrivacyRepository.ownerConflictMessage,
            ),
      ),
    );
    expect(harness.tokenStorage.values, isNotEmpty);
    expect(harness.signedOut, isEmpty);
  });

  test('a network error does not sign out or clear local data', () async {
    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          ),
    );
    final Harness harness = await buildHarness(adapter);

    await expectLater(
      harness.repository.deleteAccount(PrivacyRepository.deleteConfirmation),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.isNetwork,
          'isNetwork',
          isTrue,
        ),
      ),
    );
    expect(harness.tokenStorage.values, isNotEmpty);
    expect(harness.signedOut, isEmpty);
  });
}
