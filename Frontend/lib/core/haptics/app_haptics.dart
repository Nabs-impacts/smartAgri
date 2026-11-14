import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/language_controller.dart';

enum AppHapticType { none, tap, confirm, success, warning, error }

abstract final class AppHaptics {
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  static Future<void> trigger(AppHapticType type) async {
    if (type == AppHapticType.none || !enabled.value) {
      return;
    }
    try {
      switch (type) {
        case AppHapticType.none:
          return;
        case AppHapticType.tap:
          await HapticFeedback.selectionClick();
        case AppHapticType.confirm:
          await HapticFeedback.lightImpact();
        case AppHapticType.success:
          await HapticFeedback.mediumImpact();
        case AppHapticType.warning:
          await HapticFeedback.lightImpact();
        case AppHapticType.error:
          await HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }
}

class HapticsController extends Notifier<bool> {
  static const String storageKey = 'app_haptics';

  @override
  bool build() {
    final SharedPreferences preferences = ref.watch(sharedPreferencesProvider);
    final bool value = preferences.getBool(storageKey) ?? true;
    AppHaptics.enabled.value = value;
    return value;
  }

  Future<void> set(bool value) async {
    state = value;
    AppHaptics.enabled.value = value;
    await ref.read(sharedPreferencesProvider).setBool(storageKey, value);
  }
}

final NotifierProvider<HapticsController, bool> hapticsControllerProvider =
    NotifierProvider<HapticsController, bool>(HapticsController.new);
