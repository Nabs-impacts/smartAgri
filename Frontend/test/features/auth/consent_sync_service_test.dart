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
import 'package:smartagri/features/auth/domain/user_profile.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

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

class FixedMeController extends MeController {
  FixedMeController(this.data);

  final MeData? data;

  @override
  Future<MeData?> build() async => data;
}

MeData meData(String phone) {
  return MeData(
    user: UserProfile(
      id: 'id',
      phone: phone,
      fullName: 'Amina Diallo',
      role: 'farmer',
      language: 'fr',
    ),
    quotas: const <Quota>[],
  );
}

Future<PendingConsentsStore> buildStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  return PendingConsentsStore(preferences: preferences);
}

void main() {
  test(
    'sends the list when the current phone matches, then clears it',
    () async {
      final PendingConsentsStore store = await buildStore();
      await store.set('90203040', choices);
      final FakeAuthRepository repository = FakeAuthRepository();
      final ConsentSyncService service = ConsentSyncService(
        repository: repository,
        store: store,
      );

      await service.retryPending('+22790203040');

      expect(repository.acceptConsentsCalls, 1);
      expect(repository.lastConsents, hasLength(2));
      expect(await store.read(), isNull);
    },
  );

  test('keeps the list when the sync fails', () async {
    final PendingConsentsStore store = await buildStore();
    await store.set('90203040', choices);
    final FakeAuthRepository repository = FakeAuthRepository()
      ..acceptConsentsError = const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Impossible de joindre le serveur.',
      );
    final ConsentSyncService service = ConsentSyncService(
      repository: repository,
      store: store,
    );

    await service.retryPending('+22790203040');

    expect(repository.acceptConsentsCalls, 1);
    expect(await store.read(), isNotNull);
  });

  test('drops another phone consents without sending them', () async {
    final PendingConsentsStore store = await buildStore();
    await store.set('90203040', choices);
    final FakeAuthRepository repository = FakeAuthRepository();
    final ConsentSyncService service = ConsentSyncService(
      repository: repository,
      store: store,
    );

    await service.retryPending('+22791234567');

    expect(repository.acceptConsentsCalls, 0);
    expect(await store.read(), isNull);
  });

  test('does nothing when the current phone is unknown', () async {
    final PendingConsentsStore store = await buildStore();
    await store.set('90203040', choices);
    final FakeAuthRepository repository = FakeAuthRepository();
    final ConsentSyncService service = ConsentSyncService(
      repository: repository,
      store: store,
    );

    await service.retryPending(null);

    expect(repository.acceptConsentsCalls, 0);
    expect(await store.read(), isNotNull);
  });

  test('startup sync sends once the profile phone is known', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final FakeAuthRepository repository = FakeAuthRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authRepositoryProvider.overrideWithValue(repository),
        sessionControllerProvider.overrideWith(() => ManualSessionController()),
        meProvider.overrideWith(
          () => FixedMeController(meData('+22790203040')),
        ),
      ],
    );
    addTearDown(container.dispose);
    final PendingConsentsStore store = container.read(
      pendingConsentsStoreProvider,
    );
    await store.set('90203040', choices);
    container.read(consentSyncStartupProvider);
    await pumpEventQueue();

    expect(repository.acceptConsentsCalls, 1);
    expect(await store.read(), isNull);
  });
}
