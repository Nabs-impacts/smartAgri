import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/core/session/session_controller.dart';
import 'package:smartagri/core/session/session_events.dart';
import 'package:smartagri/core/session/session_state.dart';
import 'package:smartagri/features/profile/data/me_cache.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

import '../app_test_utils.dart';

class MutableSessionController extends SessionController {
  @override
  SessionState build() => SessionState.authenticated;

  void signOut() {
    state = SessionState.unauthenticated;
  }
}

class ExpiringSessionController extends SessionController {
  @override
  SessionState build() {
    final StreamSubscription<void> subscription = ref
        .watch(sessionEventsProvider)
        .sessionExpired
        .listen((void _) => state = SessionState.unauthenticated);
    ref.onDispose(subscription.cancel);
    return SessionState.authenticated;
  }
}

Future<String> cachedRaw(MeData data) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await MeCache(preferences: preferences).write(data);
  return preferences.getString(MeCache.storageKey)!;
}

void main() {
  test('serves the cache offline and marks it stale', () async {
    final String raw = await cachedRaw(
      sampleMeData(fullName: 'Donnée en cache'),
    );
    final FakeMeRepository repository = FakeMeRepository(
      sampleMeData(fullName: 'Donnée réseau'),
    )..error = ApiException.network();
    final ProviderContainer container = await buildTestContainer(
      meRepository: repository,
      initialPreferences: <String, Object>{MeCache.storageKey: raw},
    );

    final MeData? data = await container.read(meProvider.future);
    await pumpEventQueue();

    expect(data?.user.fullName, 'Donnée en cache');
    expect(container.read(meStaleProvider), isTrue);
    expect(repository.getMeCalls, 1);
    expect(
      container.read(sharedPreferencesProvider).getString(MeCache.storageKey),
      isNotNull,
    );
  });

  test('refreshes the cache with the network data', () async {
    final String raw = await cachedRaw(sampleMeData(fullName: 'Ancien'));
    final FakeMeRepository repository = FakeMeRepository(
      sampleMeData(fullName: 'Nouveau'),
    );
    final ProviderContainer container = await buildTestContainer(
      meRepository: repository,
      initialPreferences: <String, Object>{MeCache.storageKey: raw},
    );

    final MeData? data = await container.read(meProvider.future);
    await pumpEventQueue();

    expect(data?.user.fullName, 'Ancien');
    expect(container.read(currentUserProvider)?.fullName, 'Nouveau');
    expect(container.read(meStaleProvider), isFalse);
    expect(
      container.read(sharedPreferencesProvider).getString(MeCache.storageKey),
      contains('Nouveau'),
    );
  });

  test('clears the cache when the session is unauthenticated', () async {
    final String raw = await cachedRaw(sampleMeData());
    final ProviderContainer container = await buildTestContainer(
      meRepository: FakeMeRepository(sampleMeData()),
      session: SessionState.unauthenticated,
      initialPreferences: <String, Object>{MeCache.storageKey: raw},
    );

    final MeData? data = await container.read(meProvider.future);

    expect(data, isNull);
    expect(
      container.read(sharedPreferencesProvider).getString(MeCache.storageKey),
      isNull,
    );
  });

  test('clears the cache on sign out', () async {
    final MutableSessionController session = MutableSessionController();
    final ProviderContainer container = await buildTestContainer(
      meRepository: FakeMeRepository(sampleMeData()),
      sessionController: session,
    );
    container.listen<AsyncValue<MeData?>>(meProvider, (_, _) {});
    await container.read(meProvider.future);
    expect(
      container.read(sharedPreferencesProvider).getString(MeCache.storageKey),
      isNotNull,
    );

    session.signOut();
    await pumpEventQueue();

    expect(
      container.read(sharedPreferencesProvider).getString(MeCache.storageKey),
      isNull,
    );
  });

  test('clears the cache when the session expires', () async {
    final ExpiringSessionController session = ExpiringSessionController();
    final ProviderContainer container = await buildTestContainer(
      meRepository: FakeMeRepository(sampleMeData()),
      sessionController: session,
    );
    container.listen<AsyncValue<MeData?>>(meProvider, (_, _) {});
    await container.read(meProvider.future);
    expect(
      container.read(sharedPreferencesProvider).getString(MeCache.storageKey),
      isNotNull,
    );

    container.read(sessionEventsProvider).emitSessionExpired();
    await pumpEventQueue();

    expect(
      container.read(sharedPreferencesProvider).getString(MeCache.storageKey),
      isNull,
    );
  });

  test('ignores a cache belonging to another user', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final MeCache cache = MeCache(preferences: preferences);
    await cache.write(sampleMeData(fullName: 'Amina'));

    final MeData? other = await cache.read(userId: 'autre-utilisateur');
    final MeData? same = await cache.read(userId: 'user-id');

    expect(other, isNull);
    expect(same?.user.fullName, 'Amina');
  });
}
