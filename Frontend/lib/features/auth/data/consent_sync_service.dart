import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/phone/niger_phone.dart';
import '../../profile/data/me_repository.dart';
import '../domain/consent_choice.dart';
import 'auth_repository.dart';
import 'pending_consents_store.dart';

class ConsentSyncService {
  ConsentSyncService({required this.repository, required this.store});

  final AuthRepository repository;
  final PendingConsentsStore store;

  bool _running = false;

  Future<void> retryPending(String? currentPhone) async {
    if (_running) {
      return;
    }
    final PendingConsents? pending = await store.read();
    if (pending == null || pending.choices.isEmpty) {
      return;
    }
    if (currentPhone == null) {
      return;
    }
    final String? normalized = NigerPhone.normalize(currentPhone);
    if (normalized == null) {
      return;
    }
    if (normalized != pending.phone) {
      await store.clear();
      return;
    }
    _running = true;
    try {
      final List<ConsentChoice> choices = pending.choices;
      await repository.acceptConsents(choices);
      await store.clear();
    } catch (_) {
    } finally {
      _running = false;
    }
  }
}

final Provider<ConsentSyncService> consentSyncServiceProvider =
    Provider<ConsentSyncService>(
      (Ref ref) => ConsentSyncService(
        repository: ref.watch(authRepositoryProvider),
        store: ref.watch(pendingConsentsStoreProvider),
      ),
    );

final Provider<ConsentSyncService> consentSyncStartupProvider =
    Provider<ConsentSyncService>((Ref ref) {
      final ConsentSyncService service = ref.watch(consentSyncServiceProvider);
      ref.listen<AsyncValue<MeData?>>(meProvider, (
        AsyncValue<MeData?>? previous,
        AsyncValue<MeData?> next,
      ) {
        final String? phone = next.value?.user.phone;
        if (phone != null) {
          unawaited(service.retryPending(phone));
        }
      }, fireImmediately: true);
      return service;
    });
