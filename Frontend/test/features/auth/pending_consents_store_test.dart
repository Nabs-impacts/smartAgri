import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartagri/features/auth/data/pending_consents_store.dart';
import 'package:smartagri/features/auth/domain/consent_choice.dart';

Future<PendingConsentsStore> buildStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  return PendingConsentsStore(preferences: preferences);
}

const List<ConsentChoice> choices = <ConsentChoice>[
  ConsentChoice(type: ConsentType.terms, accepted: true),
  ConsentChoice(type: ConsentType.privacy, accepted: true),
  ConsentChoice(type: ConsentType.dataSharingGov, accepted: false),
  ConsentChoice(type: ConsentType.research, accepted: false),
];

void main() {
  test('reads nothing by default', () async {
    final PendingConsentsStore store = await buildStore();

    expect(await store.read(), isNull);
  });

  test('stores the normalized phone with every consent', () async {
    final PendingConsentsStore store = await buildStore();

    await store.set('90 20 30 40', choices);

    final PendingConsents? pending = await store.read();
    expect(pending, isNotNull);
    expect(pending!.phone, '+22790203040');
    expect(pending.choices, hasLength(4));
    expect(
      pending.choices.map((ConsentChoice choice) => choice.type),
      <ConsentType>[
        ConsentType.terms,
        ConsentType.privacy,
        ConsentType.dataSharingGov,
        ConsentType.research,
      ],
    );
    expect(pending.choices[0].accepted, isTrue);
    expect(pending.choices[3].accepted, isFalse);
  });

  test('a second set replaces the previous content', () async {
    final PendingConsentsStore store = await buildStore();
    await store.set('90203040', const <ConsentChoice>[
      ConsentChoice(type: ConsentType.research, accepted: false),
    ]);

    await store.set('91234567', const <ConsentChoice>[
      ConsentChoice(type: ConsentType.terms, accepted: true),
    ]);

    final PendingConsents? pending = await store.read();
    expect(pending, isNotNull);
    expect(pending!.phone, '+22791234567');
    expect(pending.choices, hasLength(1));
    expect(pending.choices.single.type, ConsentType.terms);
    expect(pending.choices.single.accepted, isTrue);
  });

  test('clears the stored content', () async {
    final PendingConsentsStore store = await buildStore();
    await store.set('90203040', choices);

    await store.clear();

    expect(await store.read(), isNull);
  });

  test('ignores malformed stored data', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PendingConsentsStore.storageKey: 'not-json',
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final PendingConsentsStore store = PendingConsentsStore(
      preferences: preferences,
    );

    expect(await store.read(), isNull);
    expect(preferences.getString(PendingConsentsStore.storageKey), isNull);
  });

  test('removes legacy data without a phone', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PendingConsentsStore.storageKey: jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{'type': 'terms', 'accepted': true},
      ]),
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final PendingConsentsStore store = PendingConsentsStore(
      preferences: preferences,
    );

    expect(await store.read(), isNull);
    expect(preferences.getString(PendingConsentsStore.storageKey), isNull);
  });
}
