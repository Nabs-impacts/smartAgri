import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/session/session_controller.dart';
import 'package:smartagri/core/session/session_events.dart';
import 'package:smartagri/core/session/session_state.dart';
import 'package:smartagri/core/storage/token_store.dart';
import 'package:smartagri/features/auth/data/pending_consents_store.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';

import '../storage/fake_token_storage.dart';

TokenStore emptyStore(FakeTokenStorage storage) => TokenStore(storage: storage);

Future<ProviderContainer> buildContainer(TokenStore store) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      tokenStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

const List<ConsentChoice> consentChoices = <ConsentChoice>[
  ConsentChoice(type: ConsentType.terms, accepted: true),
  ConsentChoice(type: ConsentType.research, accepted: false),
];

void main() {
  test('starts unknown then becomes unauthenticated without tokens', () async {
    final ProviderContainer container = await buildContainer(
      emptyStore(FakeTokenStorage()),
    );

    expect(container.read(sessionControllerProvider), SessionState.unknown);
    await pumpEventQueue();
    expect(
      container.read(sessionControllerProvider),
      SessionState.unauthenticated,
    );
  });

  test('becomes authenticated when tokens exist', () async {
    final FakeTokenStorage storage = FakeTokenStorage();
    final TokenStore store = TokenStore(storage: storage);
    await store.save('access', 'refresh', 3600, remember: true);
    final ProviderContainer container = await buildContainer(store);

    expect(container.read(sessionControllerProvider), SessionState.unknown);
    await pumpEventQueue();
    expect(
      container.read(sessionControllerProvider),
      SessionState.authenticated,
    );
  });

  test('signs in, signs out and reacts to session expiry', () async {
    final FakeTokenStorage storage = FakeTokenStorage();
    final ProviderContainer container = await buildContainer(
      TokenStore(storage: storage),
    );
    container.read(sessionControllerProvider);
    await pumpEventQueue();

    final SessionController controller = container.read(
      sessionControllerProvider.notifier,
    );
    await controller.signedIn(
      AuthTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
      true,
    );
    expect(
      container.read(sessionControllerProvider),
      SessionState.authenticated,
    );
    expect(storage.values[TokenStore.accessKey], 'access');

    container.read(sessionEventsProvider).emitSessionExpired();
    await pumpEventQueue();
    expect(
      container.read(sessionControllerProvider),
      SessionState.unauthenticated,
    );

    await controller.signedIn(
      AuthTokens(
        accessToken: 'access-2',
        refreshToken: 'refresh-2',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
      false,
    );
    expect(
      container.read(sessionControllerProvider),
      SessionState.authenticated,
    );

    await controller.signedOut();
    expect(
      container.read(sessionControllerProvider),
      SessionState.unauthenticated,
    );
    expect(storage.values, isEmpty);
  });

  test('clears pending consents on sign out', () async {
    final ProviderContainer container = await buildContainer(
      emptyStore(FakeTokenStorage()),
    );
    container.read(sessionControllerProvider);
    await pumpEventQueue();
    final PendingConsentsStore store = container.read(
      pendingConsentsStoreProvider,
    );
    await store.add(consentChoices);
    expect(store.read(), hasLength(2));

    await container.read(sessionControllerProvider.notifier).signedOut();

    expect(store.read(), isEmpty);
  });

  test('clears pending consents on session expiry', () async {
    final ProviderContainer container = await buildContainer(
      emptyStore(FakeTokenStorage()),
    );
    container.read(sessionControllerProvider);
    await pumpEventQueue();
    final PendingConsentsStore store = container.read(
      pendingConsentsStoreProvider,
    );
    await store.add(consentChoices);

    container.read(sessionEventsProvider).emitSessionExpired();
    await pumpEventQueue();

    expect(
      container.read(sessionControllerProvider),
      SessionState.unauthenticated,
    );
    expect(store.read(), isEmpty);
  });
}
