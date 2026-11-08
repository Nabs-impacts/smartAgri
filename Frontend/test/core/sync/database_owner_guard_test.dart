import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/database/app_database.dart';
import 'package:smartagri/core/database/database_owner_guard.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/session/session_controller.dart';
import 'package:smartagri/core/session/session_events.dart';
import 'package:smartagri/core/session/session_state.dart';
import 'package:smartagri/core/storage/token_store.dart';
import 'package:smartagri/features/auth/data/pending_consents_store.dart';
import 'package:smartagri/features/auth/domain/user_profile.dart';
import 'package:smartagri/features/privacy/data/privacy_repository.dart';
import 'package:smartagri/features/profile/data/me_cache.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

import '../network/recording_adapter.dart';
import '../storage/fake_token_storage.dart';

class _AuthenticatedSessionController extends SessionController {
  @override
  SessionState build() => SessionState.authenticated;
}

UserProfile _user(String id) {
  return UserProfile(
    id: id,
    phone: '+22790203040',
    fullName: 'Amina Diallo',
    role: 'farmer',
  );
}

Future<void> _seed(AppDatabase database) async {
  await database.upsertFarm('f1', 'Agadez');
  await database.putPendingChange(
    PendingChangesCompanion.insert(
      entity: 'farm',
      id: 'f1',
      op: 'upsert',
      payload: '{"name":"Agadez"}',
      clientUpdatedAt: DateTime.utc(2026, 11, 8, 10),
      createdAt: DateTime.utc(2026, 11, 8, 10),
    ),
  );
}

void main() {
  test('wipes the database after a successful account deletion', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    final FakeTokenStorage storage = FakeTokenStorage();
    final TokenStore tokenStore = TokenStore(storage: storage);
    await tokenStore.save('access', 'refresh', 3600, remember: true);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appDatabaseProvider.overrideWithValue(database),
        tokenStoreProvider.overrideWithValue(tokenStore),
        currentUserProvider.overrideWithValue(_user('user-1')),
      ],
    );
    addTearDown(container.dispose);

    container.read(sessionControllerProvider);
    await pumpEventQueue();
    expect(
      container.read(sessionControllerProvider),
      SessionState.authenticated,
    );
    container.read(databaseOwnerGuardProvider);
    await pumpEventQueue();
    await _seed(database);
    expect(await database.readMeta(DatabaseOwnerGuard.ownerKey), 'user-1');

    final RecordingAdapter adapter = RecordingAdapter(
      (RequestOptions options, RecordedRequest request) async =>
          body(200, <String, dynamic>{'message': 'Compte supprimé.'}),
    );
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'));
    dio.httpClientAdapter = adapter;
    final PrivacyRepository repository = PrivacyRepository(
      dio: dio,
      tokenStore: tokenStore,
      meCache: MeCache(preferences: preferences),
      pendingConsentsStore: PendingConsentsStore(preferences: preferences),
      preferences: preferences,
      onSignedOut: () =>
          container.read(sessionControllerProvider.notifier).signedOut(),
    );

    await repository.deleteAccount(PrivacyRepository.deleteConfirmation);
    await pumpEventQueue();

    expect(
      container.read(sessionControllerProvider),
      SessionState.unauthenticated,
    );
    expect(await database.getFarm('f1'), isNull);
    expect(await database.getOutbox(), isEmpty);
    expect(await database.readMeta(DatabaseOwnerGuard.ownerKey), isNull);
  });

  test('wipes the database when the session expires', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    final FakeTokenStorage storage = FakeTokenStorage();
    final TokenStore tokenStore = TokenStore(storage: storage);
    await tokenStore.save('access', 'refresh', 3600, remember: true);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appDatabaseProvider.overrideWithValue(database),
        tokenStoreProvider.overrideWithValue(tokenStore),
        currentUserProvider.overrideWithValue(_user('user-1')),
      ],
    );
    addTearDown(container.dispose);

    container.read(sessionControllerProvider);
    await pumpEventQueue();
    container.read(databaseOwnerGuardProvider);
    await pumpEventQueue();
    await _seed(database);

    container.read(sessionEventsProvider).emitSessionExpired();
    await pumpEventQueue();

    expect(
      container.read(sessionControllerProvider),
      SessionState.unauthenticated,
    );
    expect(await database.getFarm('f1'), isNull);
    expect(await database.getOutbox(), isEmpty);
    expect(await database.readMeta(DatabaseOwnerGuard.ownerKey), isNull);
  });

  test('wipes the database when the connected user changes', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    await _seed(database);
    await database.writeMeta(DatabaseOwnerGuard.ownerKey, 'user-a');
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appDatabaseProvider.overrideWithValue(database),
        sessionControllerProvider.overrideWith(
          _AuthenticatedSessionController.new,
        ),
        currentUserProvider.overrideWithValue(_user('user-b')),
      ],
    );
    addTearDown(container.dispose);

    container.read(databaseOwnerGuardProvider);
    await pumpEventQueue();

    expect(await database.getFarm('f1'), isNull);
    expect(await database.getOutbox(), isEmpty);
    expect(await database.readMeta(DatabaseOwnerGuard.ownerKey), 'user-b');
  });

  test('keeps the database for the same user', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AppDatabase database = inMemoryAppDatabase();
    addTearDown(database.close);
    await _seed(database);
    await database.writeMeta(DatabaseOwnerGuard.ownerKey, 'user-a');
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        appDatabaseProvider.overrideWithValue(database),
        sessionControllerProvider.overrideWith(
          _AuthenticatedSessionController.new,
        ),
        currentUserProvider.overrideWithValue(_user('user-a')),
      ],
    );
    addTearDown(container.dispose);

    container.read(databaseOwnerGuardProvider);
    await pumpEventQueue();

    expect(await database.getFarm('f1'), isNotNull);
    expect(await database.getOutbox(), hasLength(1));
    expect(await database.readMeta(DatabaseOwnerGuard.ownerKey), 'user-a');
  });
}
