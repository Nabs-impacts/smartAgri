import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagri/core/session/session_controller.dart';
import 'package:smartagri/core/session/session_events.dart';
import 'package:smartagri/core/session/session_state.dart';
import 'package:smartagri/core/storage/token_store.dart';

import '../storage/fake_token_storage.dart';

TokenStore emptyStore(FakeTokenStorage storage) => TokenStore(storage: storage);

void main() {
  test('starts unknown then becomes unauthenticated without tokens', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(emptyStore(FakeTokenStorage())),
      ],
    );
    addTearDown(container.dispose);

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
    final ProviderContainer container = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(sessionControllerProvider), SessionState.unknown);
    await pumpEventQueue();
    expect(
      container.read(sessionControllerProvider),
      SessionState.authenticated,
    );
  });

  test('signs in, signs out and reacts to session expiry', () async {
    final FakeTokenStorage storage = FakeTokenStorage();
    final TokenStore store = TokenStore(storage: storage);
    final ProviderContainer container = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
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
}
