import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../auth/domain/consent_choice.dart';
import 'privacy_repository.dart';

class ConsentsController extends AsyncNotifier<List<ConsentRecord>> {
  @override
  Future<List<ConsentRecord>> build() {
    return ref.read(privacyRepositoryProvider).getConsents();
  }

  Future<void> set(ConsentType type, bool accepted) async {
    final List<ConsentRecord>? previous = state.value;
    if (previous == null) {
      return;
    }
    final List<ConsentRecord> updated = <ConsentRecord>[];
    bool found = false;
    for (final ConsentRecord record in previous) {
      if (record.type == type) {
        found = true;
        updated.add(
          ConsentRecord(
            type: record.type,
            version: record.version,
            accepted: accepted,
            date: record.date,
          ),
        );
      } else {
        updated.add(record);
      }
    }
    if (!found) {
      updated.add(
        ConsentRecord(
          type: type,
          version: AppConfig.consentVersion,
          accepted: accepted,
        ),
      );
    }
    state = AsyncData<List<ConsentRecord>>(updated);
    try {
      await ref.read(privacyRepositoryProvider).setConsent(type, accepted);
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData<List<ConsentRecord>>(previous);
      }
      rethrow;
    }
  }
}

final AsyncNotifierProvider<ConsentsController, List<ConsentRecord>>
consentsProvider =
    AsyncNotifierProvider<ConsentsController, List<ConsentRecord>>(
      ConsentsController.new,
      retry: (int retryCount, Object error) => null,
    );
