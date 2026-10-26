import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/features/auth/data/pending_consents_store.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';

Future<PendingConsentsStore> buildStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  return PendingConsentsStore(preferences: preferences);
}

void main() {
  test('reads an empty list by default', () async {
    final PendingConsentsStore store = await buildStore();

    expect(store.read(), isEmpty);
  });

  test('adds every consent and reads them back', () async {
    final PendingConsentsStore store = await buildStore();
    const List<ConsentChoice> choices = <ConsentChoice>[
      ConsentChoice(type: ConsentType.terms, accepted: true),
      ConsentChoice(type: ConsentType.privacy, accepted: true),
      ConsentChoice(type: ConsentType.dataSharingGov, accepted: false),
      ConsentChoice(type: ConsentType.research, accepted: false),
    ];

    await store.add(choices);

    final List<ConsentChoice> stored = store.read();
    expect(stored, hasLength(4));
    expect(stored.map((ConsentChoice choice) => choice.type), <ConsentType>[
      ConsentType.terms,
      ConsentType.privacy,
      ConsentType.dataSharingGov,
      ConsentType.research,
    ]);
    expect(stored[0].accepted, isTrue);
    expect(stored[3].accepted, isFalse);
  });

  test('replaces an existing consent of the same type', () async {
    final PendingConsentsStore store = await buildStore();
    await store.add(const <ConsentChoice>[
      ConsentChoice(type: ConsentType.research, accepted: false),
    ]);

    await store.add(const <ConsentChoice>[
      ConsentChoice(type: ConsentType.research, accepted: true),
    ]);

    final List<ConsentChoice> stored = store.read();
    expect(stored, hasLength(1));
    expect(stored.single.accepted, isTrue);
  });

  test('clears the stored list', () async {
    final PendingConsentsStore store = await buildStore();
    await store.add(const <ConsentChoice>[
      ConsentChoice(type: ConsentType.terms, accepted: true),
    ]);

    await store.clear();

    expect(store.read(), isEmpty);
  });

  test('ignores malformed stored data', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PendingConsentsStore.storageKey: 'not-json',
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final PendingConsentsStore store = PendingConsentsStore(
      preferences: preferences,
    );

    expect(store.read(), isEmpty);
  });
}
