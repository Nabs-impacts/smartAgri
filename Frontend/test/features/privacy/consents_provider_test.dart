import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartagri/core/network/api_exception.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';
import 'package:smartagri/features/privacy/data/privacy_providers.dart';
import 'package:smartagri/features/privacy/data/privacy_repository.dart';

import 'fake_privacy_repository.dart';

const List<ConsentRecord> records = <ConsentRecord>[
  ConsentRecord(type: ConsentType.terms, version: '1.0', accepted: true),
  ConsentRecord(type: ConsentType.privacy, version: '1.0', accepted: true),
  ConsentRecord(
    type: ConsentType.dataSharingGov,
    version: '1.0',
    accepted: false,
  ),
  ConsentRecord(type: ConsentType.research, version: '1.0', accepted: false),
];

Future<ProviderContainer> buildContainer(
  FakePrivacyRepository repository,
) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [privacyRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() {
    registerFallbackValue(ConsentType.terms);
  });

  test('loads the consents list', () async {
    final FakePrivacyRepository repository = FakePrivacyRepository();
    when(repository.getConsents).thenAnswer((_) async => records);
    final ProviderContainer container = await buildContainer(repository);

    final List<ConsentRecord> loaded = await container.read(
      consentsProvider.future,
    );

    expect(loaded, hasLength(4));
    expect(loaded[2].type, ConsentType.dataSharingGov);
  });

  test('updates the state before calling the server', () async {
    final FakePrivacyRepository repository = FakePrivacyRepository();
    when(repository.getConsents).thenAnswer((_) async => records);
    when(() => repository.setConsent(ConsentType.research, true))
        .thenAnswer((_) async {});
    final ProviderContainer container = await buildContainer(repository);
    await container.read(consentsProvider.future);

    await container
        .read(consentsProvider.notifier)
        .set(ConsentType.research, true);

    final List<ConsentRecord> current = container.read(consentsProvider).value!;
    expect(current.last.type, ConsentType.research);
    expect(current.last.accepted, isTrue);
    verify(() => repository.setConsent(ConsentType.research, true)).called(1);
  });

  test('restores the previous state when the server fails', () async {
    final FakePrivacyRepository repository = FakePrivacyRepository();
    when(repository.getConsents).thenAnswer((_) async => records);
    when(() => repository.setConsent(ConsentType.research, true)).thenThrow(
      const ApiException(code: 'NETWORK_ERROR', message: 'Hors ligne.'),
    );
    final ProviderContainer container = await buildContainer(repository);
    await container.read(consentsProvider.future);

    await expectLater(
      container.read(consentsProvider.notifier).set(ConsentType.research, true),
      throwsA(isA<ApiException>()),
    );

    final List<ConsentRecord> current = container.read(consentsProvider).value!;
    expect(current.last.type, ConsentType.research);
    expect(current.last.accepted, isFalse);
  });
}
