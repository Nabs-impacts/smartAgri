import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/core/session/session_controller.dart';
import 'package:smartagri/core/session/session_state.dart';
import 'package:smartagri/features/auth/data/auth_repository.dart';
import 'package:smartagri/features/auth/data/consent_sync_service.dart';
import 'package:smartagri/features/auth/data/pending_consents_store.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';

import 'auth_test_harness.dart';

const List<ConsentChoice> choices = <ConsentChoice>[
  ConsentChoice(type: ConsentType.terms, accepted: true),
  ConsentChoice(type: ConsentType.privacy, accepted: true),
];

class ManualSessionController extends SessionController {
  @override
  SessionState build() => SessionState.unauthenticated;

  void update(SessionState value) => state = value;
}

Future<PendingConsentsStore> buildStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  return PendingConsentsStore(preferences: preferences);
}

void main() {
  test('clears the list after a successful sync', () async {
    final PendingConsentsStore store = await buildStore();
    await store.add(choices);
    final FakeAuthRepository repository = FakeAuthRepository();
    final ConsentSyncService service = ConsentSyncService(
      repository: repository,
      store: store,
    );

    await service.retryPending();

    expect(repository.acceptConsentsCalls, 1);
    expect(repository.lastConsents, hasLength(2));
    expect(store.read(), isEmpty);
  });

  test('keeps the list when the sync fails', () async {
    final PendingConsentsStore store = await buildStore();
    await store.add(choices);
    final FakeAuthRepository repository = FakeAuthRepository()
      ..acceptConsentsError = const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Impossible de joindre le serveur.',
      );
    final ConsentSyncService service = ConsentSyncService(
      repository: repository,
      store: store,
    );

    await service.retryPending();

    expect(repository.acceptConsentsCalls, 1);
    expect(store.read(), hasLength(2));
  });

  test('startup sync runs when the session becomes authenticated', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final FakeAuthRepository repository = FakeAuthRepository();
    final ManualSessionController session = ManualSessionController();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authRepositoryProvider.overrideWithValue(repository),
        sessionControllerProvider.overrideWith(() => session),
      ],
    );
    addTearDown(container.dispose);
    final PendingConsentsStore store = container.read(
      pendingConsentsStoreProvider,
    );
    await store.add(choices);
    container.read(consentSyncStartupProvider);

    session.update(SessionState.authenticated);
    await pumpEventQueue();

    expect(repository.acceptConsentsCalls, 1);
    expect(store.read(), isEmpty);
  });

  test('does nothing when the list is empty', () async {
    final PendingConsentsStore store = await buildStore();
    final FakeAuthRepository repository = FakeAuthRepository();
    final ConsentSyncService service = ConsentSyncService(
      repository: repository,
      store: store,
    );

    await service.retryPending();

    expect(repository.acceptConsentsCalls, 0);
  });
}
