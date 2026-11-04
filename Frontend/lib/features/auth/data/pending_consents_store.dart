import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/language_controller.dart';
import '../../../core/phone/niger_phone.dart';
import '../domain/consent_choice.dart';

class PendingConsents {
  const PendingConsents({required this.phone, required this.choices});

  final String phone;
  final List<ConsentChoice> choices;
}

class PendingConsentsStore {
  PendingConsentsStore({required this.preferences});

  static const String storageKey = 'pending_consents';

  final SharedPreferences preferences;

  Future<void> set(String phone, List<ConsentChoice> choices) async {
    final String normalized = NigerPhone.normalize(phone) ?? phone;
    await preferences.setString(
      storageKey,
      jsonEncode(<String, dynamic>{
        'phone': normalized,
        'choices': choices
            .map(
              (ConsentChoice choice) => <String, dynamic>{
                'type': choice.type.apiValue,
                'accepted': choice.accepted,
              },
            )
            .toList(),
      }),
    );
  }

  Future<PendingConsents?> read() async {
    final String? raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clear();
        return null;
      }
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
      final Object? phone = map['phone'];
      final Object? rawChoices = map['choices'];
      if (phone is! String || phone.isEmpty || rawChoices is! List) {
        await clear();
        return null;
      }
      final List<ConsentChoice> choices = rawChoices
          .map(_fromJson)
          .whereType<ConsentChoice>()
          .toList(growable: true);
      return PendingConsents(phone: phone, choices: choices);
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    await preferences.remove(storageKey);
  }

  ConsentChoice? _fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final Object? typeValue = value['type'];
    final Object? accepted = value['accepted'];
    if (typeValue is! String || accepted is! bool) {
      return null;
    }
    for (final ConsentType type in ConsentType.values) {
      if (type.apiValue == typeValue) {
        return ConsentChoice(type: type, accepted: accepted);
      }
    }
    return null;
  }
}

final Provider<PendingConsentsStore> pendingConsentsStoreProvider =
    Provider<PendingConsentsStore>(
      (Ref ref) => PendingConsentsStore(
        preferences: ref.watch(sharedPreferencesProvider),
      ),
    );
