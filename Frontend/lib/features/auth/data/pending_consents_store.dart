import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/i18n/language_controller.dart';
import '../domain/consent_choice.dart';

class PendingConsentsStore {
  PendingConsentsStore({required this.preferences});

  static const String storageKey = 'pending_consents';

  final SharedPreferences preferences;

  Future<void> add(List<ConsentChoice> choices) async {
    final List<ConsentChoice> merged = read();
    for (final ConsentChoice choice in choices) {
      merged.removeWhere(
        (ConsentChoice existing) => existing.type == choice.type,
      );
      merged.add(choice);
    }
    await preferences.setString(
      storageKey,
      jsonEncode(
        merged
            .map(
              (ConsentChoice choice) => <String, dynamic>{
                'type': choice.type.apiValue,
                'accepted': choice.accepted,
              },
            )
            .toList(),
      ),
    );
  }

  List<ConsentChoice> read() {
    final String? raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return <ConsentChoice>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <ConsentChoice>[];
      }
      return decoded
          .map(_fromJson)
          .whereType<ConsentChoice>()
          .toList(growable: true);
    } on FormatException {
      return <ConsentChoice>[];
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
