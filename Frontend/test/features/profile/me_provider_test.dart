import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartagri/core/i18n/app_language.dart';
import 'package:smartagri/core/i18n/language_controller.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/core/session/session_state.dart';
import 'package:smartagri/features/auth/domain/user_profile.dart';
import 'package:smartagri/features/profile/data/me_repository.dart';

import '../app_test_utils.dart';

void main() {
  test('loads when authenticated and updates the current user', () async {
    final FakeMeRepository repository = FakeMeRepository(sampleMeData());
    final ProviderContainer container = await buildTestContainer(
      meRepository: repository,
    );

    final MeData? data = await container.read(meProvider.future);

    expect(data?.user.fullName, 'Amina Diallo');
    expect(repository.getMeCalls, 1);
    expect(container.read(currentUserProvider)?.fullName, 'Amina Diallo');
  });

  test('does not load when the session is unauthenticated', () async {
    final FakeMeRepository repository = FakeMeRepository(sampleMeData());
    final ProviderContainer container = await buildTestContainer(
      meRepository: repository,
      session: SessionState.unauthenticated,
    );

    final MeData? data = await container.read(meProvider.future);

    expect(data, isNull);
    expect(repository.getMeCalls, 0);
    expect(container.read(currentUserProvider), isNull);
  });

  test('refresh replaces the data and the current user', () async {
    final FakeMeRepository repository = FakeMeRepository(sampleMeData());
    final ProviderContainer container = await buildTestContainer(
      meRepository: repository,
    );
    await container.read(meProvider.future);

    repository.data = sampleMeData(fullName: 'Moussa Issoufou');
    await container.read(meProvider.notifier).refresh();

    expect(container.read(currentUserProvider)?.fullName, 'Moussa Issoufou');
    expect(container.read(meProvider).value?.user.fullName, 'Moussa Issoufou');
    expect(container.read(meStaleProvider), isFalse);
  });

  test('a failed refresh keeps the previous data and marks it stale', () async {
    final FakeMeRepository repository = FakeMeRepository(sampleMeData());
    final ProviderContainer container = await buildTestContainer(
      meRepository: repository,
    );
    final MeData? initial = await container.read(meProvider.future);

    repository.error = ApiException.network();
    await container.read(meProvider.notifier).refresh();

    expect(container.read(meProvider).value, same(initial));
    expect(container.read(currentUserProvider)?.fullName, 'Amina Diallo');
    expect(container.read(meStaleProvider), isTrue);
  });

  test('an initial network failure exposes an error', () async {
    final FakeMeRepository repository = FakeMeRepository(sampleMeData())
      ..error = ApiException.network();
    final ProviderContainer container = await buildTestContainer(
      meRepository: repository,
    );

    await expectLater(
      container.read(meProvider.future),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(meProvider).hasError, isTrue);
  });

  test('a language change updates the backend in the background', () async {
    final FakeMeRepository repository = FakeMeRepository(sampleMeData());
    final ProviderContainer container = await buildTestContainer(
      meRepository: repository,
    );
    await container.read(meProvider.future);

    await container
        .read(languageControllerProvider.notifier)
        .set(AppLanguage.dje);
    await Future<void>.delayed(Duration.zero);

    expect(repository.languages, contains(AppLanguage.dje));
  });

  test('a language update failure stays silent', () async {
    final FakeMeRepository repository = FakeMeRepository(sampleMeData());
    final ProviderContainer container = await buildTestContainer(
      meRepository: repository,
    );
    await container.read(meProvider.future);
    repository.error = ApiException.network();

    await container
        .read(languageControllerProvider.notifier)
        .set(AppLanguage.ha);
    await Future<void>.delayed(Duration.zero);

    expect(repository.updateLanguageCalls, 1);
    expect(container.read(currentUserProvider), isA<UserProfile>());
  });
}
